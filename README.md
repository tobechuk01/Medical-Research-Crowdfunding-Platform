# Medical Research Crowdfunding Platform

A blockchain-based transparent system where people can fund specific medical research initiatives, track progress via verifiable milestones, and potentially share in intellectual property rights.

## Overview

This smart contract enables:
- Creation of medical research funding campaigns
- Milestone-based funding release
- IP rights distribution to funders
- Transparent progress tracking
- Secure fund management

## Features

- **Campaign Creation**: Researchers can create funding campaigns with goals and deadlines
- **Milestone Tracking**: Break research into verifiable milestones
- **Transparent Funding**: All transactions are recorded on the blockchain
- **IP Rights Sharing**: Funders can receive intellectual property rights
- **Secure Withdrawals**: Automated fund release upon milestone completion

## Smart Contract Functions

### Public Functions
- `create-campaign`: Create a new research funding campaign
- `add-milestone`: Add milestones to track research progress
- `fund-campaign`: Contribute STX tokens to a campaign
- `complete-milestone`: Mark milestone as completed with verification
- `verify-milestone`: Verify completed milestones
- `withdraw-unsuccessful-funding`: Withdraw funds from unsuccessful campaigns

### Read-Only Functions
- `get-campaign`: Retrieve campaign details
- `get-milestone`: Get milestone information
- `get-funder-info`: Check funding contributions
- `get-ip-rights`: View IP rights allocation

## Technology Stack

- **Blockchain**: Stacks Network
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet

## Getting Started

1. Clone this repository
2. Install Clarinet: `npm install -g @hirosystems/clarinet-cli`
3. Run `clarinet check` to validate the contract
4. Deploy using `clarinet deploy`

## Usage Example

```clarity
;; Create a campaign
(contract-call? .medical-research-crowdfunding create-campaign 
  "Cancer Treatment Research" 
  "Developing new immunotherapy treatments" 
  u1000000 
  u52560 
  u2000)

;; Fund a campaign
(contract-call? .medical-research-crowdfunding fund-campaign u1 u100000)
## Development Status

✅ Smart contract implementation complete
✅ Core functionality tested and verified
✅ Documentation and setup guides provided

Ready for deployment and testing on Stacks testnet.
