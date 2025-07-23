;; Medical Research Crowdfunding Platform
;; A transparent system for funding medical research initiatives with milestone tracking

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-campaign-ended (err u104))
(define-constant err-campaign-not-ended (err u105))
(define-constant err-milestone-not-completed (err u106))
(define-constant err-already-funded (err u107))
(define-constant err-insufficient-funds (err u108))
(define-constant err-invalid-milestone (err u109))

;; Data Variables
(define-data-var next-campaign-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var platform-fee uint u250) ;; 2.5% in basis points

;; Data Maps
(define-map campaigns
  { campaign-id: uint }
  {
    researcher: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    status: (string-ascii 20),
    ip-share-percentage: uint,
    created-at: uint
  }
)

(define-map campaign-funders
  { campaign-id: uint, funder: principal }
  {
    amount: uint,
    funded-at: uint,
    ip-rights: bool
  }
)

(define-map milestones
  { milestone-id: uint }
  {
    campaign-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    funding-release: uint,
    status: (string-ascii 20),
    verification-hash: (optional (buff 32)),
    completed-at: (optional uint)
  }
)

(define-map campaign-milestones
  { campaign-id: uint }
  { milestone-ids: (list 20 uint) }
)

(define-map ip-rights
  { campaign-id: uint, holder: principal }
  { percentage: uint, active: bool }
)

;; Public Functions

;; Create a new research campaign
(define-public (create-campaign 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (funding-goal uint)
    (deadline uint)
    (ip-share-percentage uint))
  (let 
    (
      (campaign-id (var-get next-campaign-id))
    )
    (asserts! (> funding-goal u0) err-invalid-amount)
    (asserts! (> deadline block-height) err-invalid-amount)
    (asserts! (<= ip-share-percentage u10000) err-invalid-amount) ;; Max 100%
    
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        researcher: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        deadline: deadline,
        status: "active",
        ip-share-percentage: ip-share-percentage,
        created-at: block-height
      }
    )
    
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

;; Add milestone to campaign
(define-public (add-milestone
    (campaign-id uint)
    (title (string-ascii 100))
    (description (string-ascii 300))
    (funding-release uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (milestone-id (var-get next-milestone-id))
      (current-milestones (default-to (list) (get milestone-ids (map-get? campaign-milestones { campaign-id: campaign-id }))))
    )
    (asserts! (is-eq tx-sender (get researcher campaign)) err-unauthorized)
    (asserts! (> funding-release u0) err-invalid-amount)
    (asserts! (is-eq (get status campaign) "active") err-campaign-ended)
    
    (map-set milestones
      { milestone-id: milestone-id }
      {
        campaign-id: campaign-id,
        title: title,
        description: description,
        funding-release: funding-release,
        status: "pending",
        verification-hash: none,
        completed-at: none
      }
    )
    
    (map-set campaign-milestones
      { campaign-id: campaign-id }
      { milestone-ids: (unwrap! (as-max-len? (append current-milestones milestone-id) u20) err-invalid-milestone) }
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

;; Fund a research campaign
(define-public (fund-campaign (campaign-id uint) (amount uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (existing-funding (default-to u0 (get amount (map-get? campaign-funders { campaign-id: campaign-id, funder: tx-sender }))))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq (get status campaign) "active") err-campaign-ended)
    (asserts! (<= block-height (get deadline campaign)) err-campaign-ended)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update campaign funding
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { current-funding: (+ (get current-funding campaign) amount) })
    )
    
    ;; Update funder record
    (map-set campaign-funders
      { campaign-id: campaign-id, funder: tx-sender }
      {
        amount: (+ existing-funding amount),
        funded-at: block-height,
        ip-rights: true
      }
    )
    
    ;; Grant IP rights if applicable
    (if (> (get ip-share-percentage campaign) u0)
      (grant-ip-rights campaign-id tx-sender amount (get current-funding campaign) (get ip-share-percentage campaign))
      (ok true)
    )
  )
)

;; Complete milestone with verification
(define-public (complete-milestone (milestone-id uint) (verification-hash (buff 32)))
  (let
    (
      (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found))
      (campaign (unwrap! (map-get? campaigns { campaign-id: (get campaign-id milestone) }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get researcher campaign)) err-unauthorized)
    (asserts! (is-eq (get status milestone) "pending") err-milestone-not-completed)
    
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone {
        status: "completed",
        verification-hash: (some verification-hash),
        completed-at: (some block-height)
      })
    )
    
    ;; Release funds to researcher
    (try! (as-contract (stx-transfer? (get funding-release milestone) tx-sender (get researcher campaign))))
    
    (ok true)
  )
)

;; Verify milestone (by platform or community)
(define-public (verify-milestone (milestone-id uint) (approved bool))
  (let
    (
      (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) err-not-found))
    )
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (as-contract tx-sender))) err-unauthorized)
    
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone {
        status: (if approved "verified" "rejected")
      })
    )
    
    (ok approved)
  )
)

;; Withdraw funds after campaign deadline
(define-public (withdraw-unsuccessful-funding (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
      (funder-info (unwrap! (map-get? campaign-funders { campaign-id: campaign-id, funder: tx-sender }) err-not-found))
    )
    (asserts! (> block-height (get deadline campaign)) err-campaign-not-ended)
    (asserts! (< (get current-funding campaign) (get funding-goal campaign)) err-already-funded)
    
    ;; Return funds to funder
    (try! (as-contract (stx-transfer? (get amount funder-info) tx-sender tx-sender)))
    
    ;; Remove funder record
    (map-delete campaign-funders { campaign-id: campaign-id, funder: tx-sender })
    
    (ok (get amount funder-info))
  )
)

;; Emergency pause campaign (owner only)
(define-public (pause-campaign (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (map-set campaigns
      { campaign-id: campaign-id }
      (merge campaign { status: "paused" })
    )
    
    (ok true)
  )
)

;; Private Functions

;; Grant IP rights to funders
(define-private (grant-ip-rights (campaign-id uint) (funder principal) (amount uint) (total-funding uint) (ip-percentage uint))
  (let
    (
      (funder-percentage (/ (* amount ip-percentage) total-funding))
    )
    (map-set ip-rights
      { campaign-id: campaign-id, holder: funder }
      {
        percentage: funder-percentage,
        active: true
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get campaign details
(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

;; Get milestone details
(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

;; Get campaign milestones
(define-read-only (get-campaign-milestones (campaign-id uint))
  (map-get? campaign-milestones { campaign-id: campaign-id })
)

;; Get funder info
(define-read-only (get-funder-info (campaign-id uint) (funder principal))
  (map-get? campaign-funders { campaign-id: campaign-id, funder: funder })
)

;; Get IP rights
(define-read-only (get-ip-rights (campaign-id uint) (holder principal))
  (map-get? ip-rights { campaign-id: campaign-id, holder: holder })
)

;; Get next campaign ID
(define-read-only (get-next-campaign-id)
  (var-get next-campaign-id)
)

;; Get platform fee
(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

;; Check if campaign is fully funded
(define-read-only (is-campaign-funded (campaign-id uint))
  (match (map-get? campaigns { campaign-id: campaign-id })
    campaign (>= (get current-funding campaign) (get funding-goal campaign))
    false
  )
)