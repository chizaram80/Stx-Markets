# Prediction Market Smart Contract

## Overview
This smart contract implements a decentralized prediction market platform on the Stacks blockchain. Users can create markets for future events, stake STX tokens on different outcomes, and earn rewards for correct predictions. The contract includes features for market creation, stake management, automated resolution, and reward distribution.

## Key Features
- Create prediction markets with multiple outcome options
- Stake STX tokens on predicted outcomes
- Partial stake withdrawal before market resolution
- Automatic market resolution based on block height
- Platform fee system (2% of winnings)
- Market cancellation functionality
- Reward distribution system for winning predictions

## Technical Specifications
- Minimum stake amount: 100,000 microSTX
- Platform commission rate: 2%
- Maximum market ID: 1,000,000
- Maximum options per market: 20
- Maximum question length: 256 characters
- Maximum description length: 1,024 characters

## Contract Functions

### Market Creation and Management

#### create-prediction-market
Creates a new prediction market with specified parameters.
```clarity
(create-prediction-market 
    (prediction-question (string-ascii 256)) 
    (market-details (string-ascii 1024)) 
    (resolution-block-height uint) 
    (available-predictions (list 20 (string-ascii 64))))
```
- Parameters:
  - `prediction-question`: Main question of the market
  - `market-details`: Detailed description of the market
  - `resolution-block-height`: Block height at which the market can be resolved
  - `available-predictions`: List of possible outcome options
- Returns: Market identifier (uint)

#### place-prediction-stake
Places a stake on a specific prediction option.
```clarity
(place-prediction-stake 
    (market-identifier uint) 
    (prediction-index uint) 
    (stake-amount uint))
```
- Parameters:
  - `market-identifier`: ID of the target market
  - `prediction-index`: Index of the chosen prediction option
  - `stake-amount`: Amount of STX to stake (minimum 100,000 microSTX)

### Market Resolution

#### resolve-prediction-market
Manually resolves a market with the winning prediction (admin only).
```clarity
(resolve-prediction-market 
    (market-identifier uint) 
    (winning-prediction-index uint))
```

#### auto-resolve-markets
Automatically resolves multiple expired markets.
```clarity
(auto-resolve-markets (max-resolution-count uint))
```

### Stake Management

#### withdraw-partial-stake
Allows partial withdrawal of staked amounts before market resolution.
```clarity
(withdraw-partial-stake 
    (market-identifier uint) 
    (prediction-index uint) 
    (withdrawal-amount uint))
```

#### claim-rewards-or-refund
Claims winnings for resolved markets or refunds for cancelled markets.
```clarity
(claim-rewards-or-refund (market-identifier uint))
```

### Read-Only Functions

#### get-market-info
```clarity
(get-market-info (market-identifier uint))
```
Returns market details including question, description, and current state.

#### get-prediction-options
```clarity
(get-prediction-options (market-identifier uint))
```
Returns available prediction options for a market.

#### get-participant-predictions
```clarity
(get-participant-predictions (market-identifier uint) (participant-address principal))
```
Returns stake information for a specific participant.

#### get-contract-balance
```clarity
(get-contract-balance)
```
Returns the current STX balance of the contract.

## Error Codes
- `ERROR_UNAUTHORIZED` (100): Unauthorized access attempt
- `ERROR_MARKET_ALREADY_RESOLVED` (101): Market has already been resolved
- `ERROR_MARKET_NOT_RESOLVED` (102): Market has not been resolved yet
- `ERROR_INVALID_STAKE_AMOUNT` (103): Invalid stake amount
- `ERROR_INSUFFICIENT_BALANCE` (104): Insufficient balance for operation
- `ERROR_MARKET_CANCELLED` (105): Market has been cancelled
- `ERROR_INVALID_OPTION` (106): Invalid prediction option
- `ERROR_INVALID_MARKET_ID` (107): Invalid market identifier
- `ERROR_INVALID_END_BLOCK` (108): Invalid resolution block height
- `ERROR_INVALID_QUESTION` (109): Invalid market question
- `ERROR_INVALID_DESCRIPTION` (110): Invalid market description

## Security Considerations
1. All stake operations are protected with balance checks
2. Market resolution is restricted to administrator access
3. Automatic resolution is based on immutable block height
4. Stake withdrawals are only allowed before market resolution
5. Market cancellation is restricted to administrator access

## Usage Example
```clarity
;; Create a new prediction market
(create-prediction-market 
    "Will BTC price exceed $100k in 2025?"
    "Prediction market for Bitcoin price milestone"
    u100000
    (list "Yes" "No"))

;; Place a stake on an option
(place-prediction-stake u1 u0 u200000)

;; Claim rewards after market resolution
(claim-rewards-or-refund u1)
```

## Development and Testing
To deploy and test this contract:
1. Ensure you have a Stacks blockchain development environment
2. Deploy the contract using Clarinet or similar tools
3. Test all functions with various scenarios
4. Pay special attention to error handling and edge cases