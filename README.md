# EQTY Contracts

Smart contracts for the EQTY protocol on Base.

## Contracts

| Contract | Description |
|----------|-------------|
| **EQTY.sol** | ERC20 token with 500M cap, bridge-controlled minting, and burn functionality |
| **Anchor.sol** | Stateless anchoring contract for recording event chain hashes (burns EQTY as fee) |
| **RedeemEQTY.sol** | Allows users to redeem EQTY tokens for ETH from protocol fees |

## Quick Start

### Prerequisites

Install [Foundry](https://book.getfoundry.sh/getting-started/installation):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Install Dependencies

```bash
forge install
npm install  # For OpenZeppelin contracts
```

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Verbose output
forge test -vvv

# With gas report
forge test --gas-report

# Specific test file
forge test --match-path test/Anchor.t.sol
```

### Deploy

1. Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

1. Deploy to Base Sepolia:

```bash
# Deploy EQTY token
forge script script/DeployEQTY.s.sol --rpc-url base-sepolia --broadcast --verify

# Deploy Anchor
forge script script/DeployAnchor.s.sol --rpc-url base-sepolia --broadcast --verify

# Deploy RedeemEQTY
forge script script/DeployRedeem.s.sol --rpc-url base-sepolia --broadcast --verify
```

1. Deploy to Base Mainnet:

```bash
forge script script/DeployAnchor.s.sol --rpc-url base --broadcast --verify
```

## Project Structure

```
eqty-contracts/
├── src/                    # Contract source files
│   ├── Anchor.sol
│   ├── EQTY.sol
│   ├── RedeemEQTY.sol
│   └── interfaces/
│       └── IAnchor.sol
├── test/                   # Foundry tests (Solidity)
│   ├── Anchor.t.sol
│   ├── EQTY.t.sol
│   └── RedeemEQTY.t.sol
├── script/                 # Deployment scripts
│   ├── DeployAnchor.s.sol
│   ├── DeployEQTY.s.sol
│   └── DeployRedeem.s.sol
├── foundry.toml            # Foundry configuration
└── package.json            # NPM dependencies (OpenZeppelin)
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `PRIVATE_KEY` | Deployer private key |
| `BASE_MAINNET_RPC_URL` | Base mainnet RPC URL |
| `BASE_SEPOLIA_RPC_URL` | Base Sepolia RPC URL |
| `BASESCAN_API_KEY` | Basescan API key for verification |
| `EQTY_TOKEN_ADDRESS` | EQTY token address (for Anchor deployment) |
| `BRIDGE_WALLET` | Bridge wallet address (for EQTY deployment) |
| `FOUNDATION_WALLET` | Foundation wallet (for RedeemEQTY deployment) |

## Gas Optimization

All contracts are optimized for gas efficiency on Base L2:

- `via_ir` enabled for advanced optimizations
- 200 optimizer runs (balanced for deployment + usage)
- Minimal storage operations in Anchor (stateless design)
- Packed storage in RedeemEQTY

## Security

| Contract | Features |
|----------|----------|
| **Anchor** | `Ownable2Step` (2-step ownership transfer) |
| **EQTY** | Immutable bridge wallet, mint deadline |
| **RedeemEQTY** | `Ownable2Step`, `ReentrancyGuard`, `SafeERC20` |

**Note:** `Ownable2Step` requires new owner to call `acceptOwnership()` after transfer.

## License

MIT
