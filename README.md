# EQTY Anchor Contract

A lightweight, gas-efficient anchoring contract for recording event chain hashes on Base blockchain. This contract enables the EQTY protocol to anchor state transitions and messages on-chain with minimal gas costs.

## Overview

The Anchor contract provides a stateless solution for recording cryptographic hashes on-chain through events. By using events instead of storage, the contract achieves ~90% gas savings compared to traditional storage-based approaches while maintaining full auditability.

### Key Features

- **Stateless Architecture**: All data recorded via events only
- **Batch Anchoring**: Submit up to 100 anchors in a single transaction
- **Fee Mechanism**: Optional EQTY token burning for spam prevention (currently deployed with 0 fee)
- **Ownable**: Fee configuration managed by contract owner
- **Gas Optimized**: Minimal storage operations for maximum efficiency

## Contracts

### Anchor.sol
The main anchoring contract that:
- Records key-value pairs (hashes) via events
- Charges fees in EQTY tokens (burned)
- Supports batch submissions
- Implements Ownable2Step for secure ownership transfer

### EQTY.sol
The ERC20 token used for fee payments:
- Standard ERC20 with burn functionality
- **Capped Supply**: Maximum 500 million EQTY tokens (using OpenZeppelin's ERC20Capped)
- **Bridge Minting**: Only designated bridge wallet can mint
- **Time-Limited Minting**: Minting restricted until specified deadline
- **Burnable**: Tokens burned as payment for anchoring operations

### IAnchor.sol
Interface defining the anchor structure and events.

## Deployments

### Base Sepolia (Testnet)
- **Anchor Contract**: [`0x7607af0cea78815c71bbea90110b2c218879354b`](https://sepolia.basescan.org/address/0x7607af0cea78815c71bbea90110b2c218879354b#code)
  - Deployed with no EQTY token requirement and 0 fee
  - Verified on Basescan

## Installation

```bash
npm install
```

## Configuration

Create a `.env` file based on `.env.example`:

```bash
# Required for deployment
PRIVATE_KEY=your_private_key_here

# For EQTY token deployment
BRIDGE_WALLET=0x... # Bridge wallet address that can mint EQTY
MINT_DEADLINE=2025-10-01T00:00:00Z # Optional, defaults to 90 days from now

# RPC URLs (optional, defaults to public endpoints)
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_MAINNET_RPC_URL=https://mainnet.base.org

# For contract verification
BASESCAN_API_KEY=your_basescan_api_key
```

## Usage

### Compile Contracts
```bash
npm run compile
```

### Run Tests
```bash
npm test
```

### Run Tests with Coverage
```bash
npm run test:coverage
```

### Run Gas Reports
```bash
npm run test:gas
```

### Deploy Contracts

#### Deploy EQTY Token

Deploy EQTY token with bridge minting capability:

```bash
# Deploy to Base Sepolia
npx hardhat run scripts/deploy-eqty.ts --network base-sepolia

# Deploy to Base mainnet
npx hardhat run scripts/deploy-eqty.ts --network base
```

Environment variables:
- `BRIDGE_WALLET` - Address that can mint EQTY tokens
- `MINT_DEADLINE` - ISO Date to when minting is allowed (optional, defaults to 90 days from now)

#### Deploy Anchor Contract

Deploy the Anchor contract (currently configured with no EQTY requirement and 0 fee):

```bash
# Deploy to Base Sepolia
npm run deploy:base-sepolia

# Deploy to Base mainnet
npm run deploy:base
```

**Note**: The deployment script uses Viem directly to avoid chain ID conflicts. Make sure your `.env` file contains:
- `PRIVATE_KEY` - Your deployer private key (without 0x prefix)
- `BASE_SEPOLIA_RPC_URL` - RPC URL for Base Sepolia (optional, defaults to public RPC)
- `BASE_MAINNET_RPC_URL` - RPC URL for Base mainnet (optional, defaults to public RPC)
- `BASESCAN_API_KEY` - For contract verification

### Verify Contracts
```bash
npm run verify -- <contract_address> --network <network>
```

## Contract Usage

### Anchoring Data

To anchor data on-chain:

```solidity
// Create anchor array
IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
anchors[0] = IAnchor.Anchor({
    key: stateHash,    // For event chains: previous state hash
    value: eventHash   // For event chains: event hash
});

// Approve EQTY tokens for burning
eqtyToken.approve(anchorAddress, fee);

// Submit anchors
anchor.anchor(anchors);
```

### Batch Anchoring

Submit multiple anchors in one transaction:

```solidity
IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](count);
// ... populate anchors array
anchor.anchor(anchors);
```

## Architecture

### Event-Based Storage

The contract uses events exclusively for data storage:
- `Anchored` event stores the key, value, sender, and timestamp
- Events are indexed for efficient off-chain querying
- No contract storage used for anchor data

### Fee Mechanism

- Fees are paid in EQTY tokens
- Tokens are burned (removed from circulation)
- Fee amount configurable by owner
- Zero fee possible (set fee to 0)

### Security

- Ownable2Step: Two-step ownership transfer for added security
- No reentrancy risks: No external calls after state changes
- Gas limits: Maximum 100 anchors per transaction

## Gas Optimization

The contract is optimized for minimal gas usage:
- Events instead of storage (~90% savings)
- Cached timestamp for batch operations
- Unchecked increment in loops (safe due to array bounds)
- Minimal storage slots (only fee and token address)

## Testing

The test suite includes:
- Unit tests for all functions
- Gas optimization tests
- Batch operation tests
- Edge case coverage

## License

MIT License - see LICENSE file for details

## Security

For security concerns, please contact: security@eqty.network
