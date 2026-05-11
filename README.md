# EQTY Contracts

Smart contracts for the EQTY protocol on Base.

## Overview

The EQTY protocol creates a **Real Yield Loop** where:

1. **Builders/Services** pay fees via Anchor (ETH or EQTY)
2. **ETH accumulates** in the Redeem contract
3. **EQTY holders** can redeem tokens for ETH at a dynamic rate
4. **EQTY is burned** → deflationary tokenomics

This creates a self-sustaining ecosystem where EQTY value is backed by actual protocol revenue.

## Contracts

| Contract | Description |
|----------|-------------|
| **EQTY.sol** | ERC20 token with 500M cap, bridge-controlled minting, and burn functionality |
| **Anchor.sol** | Stateless anchoring contract - accepts ETH or EQTY for fee payment |
| **Redeem.sol** | Dynamic rate redemption of EQTY for ETH with exact-output execution |

Detailed contract docs:
- [Anchor.md](./Anchor.md)
- [Redeem.md](./Redeem.md)

### Canonical Public Events

Anchor can emit canonical `PublicEvent` logs for subject-specific integrations.

`emitPublicEvent` can be used in two ways:
- an external contract can call Anchor as part of its own flow
- an Ownable owner can call Anchor directly

In both cases, the immediate caller is the emitted `source` and the payer. Which sources are semantically accepted is decided by the Ownable implementation, not by Anchor.

The public-event `eventType` is stored as a readable string so it remains understandable when users sign event-triggering actions.

See [Anchor.md](./Anchor.md) for the detailed behavior, payment model, and trust model.

## Architecture

```mermaid
graph LR
    A[Builders] -->|ETH| B[Anchor]
    A -->|EQTY| D[Burned]
    B -->|ETH forwarded| C[Redeem]
    C -->|rate| B
    E[EQTY Holders] -->|redeemAmount EQTY| C
    C -->|ETH| E
    E -->|burned| D
```

Anchor accepts payment in either ETH or EQTY. ETH is forwarded to `Redeem`, while EQTY is burned. See [Anchor.md](./Anchor.md) for details.

## Dynamic Exchange Rate

The exchange rate **self-adjusts** based on actual redemption activity:

```
r_next = r × clamp(p / r, 0.9, 1.1)
```

| Term | Meaning |
|------|---------|
| `r` | Current exchange rate (ETH per redeem amount) |
| `p` | Actual ETH paid out |
| `0.9, 1.1` | Max ±10% change per transaction |

**How it works:**

- More ETH in contract than rate → Rate increases gradually
- Less ETH in contract than rate → Rate decreases gradually
- Rate naturally finds equilibrium based on protocol revenue

**Initial exchange rate** and **redeem amount** are set at deployment, then the system self-adjusts.

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

1. Deploy contracts in order:

```bash
# 1. Optional: deploy EQTY token separately
forge script script/DeployEQTY.s.sol --rpc-url base-sepolia --broadcast --verify

# 2. Deploy Redeem
# - reuses EQTY_TOKEN_ADDRESS when set
# - otherwise deploys EQTY first on Base Sepolia using BRIDGE_WALLET
forge script script/DeployRedeem.s.sol --rpc-url base-sepolia --broadcast --verify

# 3. Deploy Anchor (needs EQTY and Redeem addresses)
forge script script/DeployAnchor.s.sol --rpc-url base-sepolia --broadcast --verify
```

On Base Sepolia, `DeployRedeem` will deploy a new EQTY token when `EQTY_TOKEN_ADDRESS` is unset. If you already have a testnet EQTY deployment, set `EQTY_TOKEN_ADDRESS` and the script will reuse it instead.

1. Post-deployment configuration:

```solidity
// Configure Anchor to point to Redeem
anchorContract.setRedeemContract(redeemAddress);
anchorContract.setEqtyToken(eqtyAddress);
anchorContract.setEqtyFee(100 ether); // 100 EQTY per anchor (DAO-configurable)
```

## Project Structure

```
eqty-contracts/
├── Anchor.md               # Detailed Anchor docs
├── Redeem.md               # Detailed Redeem docs
├── src/                    # Contract source files
│   ├── Anchor.sol          # Anchoring with ETH/EQTY payment
│   ├── EQTY.sol            # ERC20 token
│   ├── Redeem.sol          # Dynamic rate redemption
│   └── interfaces/
│       ├── IAnchor.sol     # Anchor interface
│       └── IRedeem.sol     # Redeem interface
├── test/                   # Foundry tests
│   ├── Anchor.t.sol
│   ├── EQTY.t.sol
│   └── Redeem.t.sol
├── script/                 # Deployment scripts
│   ├── DeployAnchor.s.sol
│   ├── DeployEQTY.s.sol
│   └── DeployRedeem.s.sol
├── foundry.toml            # Foundry configuration
└── package.json            # NPM dependencies
```

## Deployed Addresses

### Base Mainnet

| Contract | Address |
|----------|---------|
| EQTY Token | `0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29` |
| Treasury | `0x2Bc456799F3Cf071B10CE7216269471e0A40381a` |
| Anchor | *Pending deployment* |
| Redeem | *Pending deployment* |

### Base Sepolia (Testnet)

| Contract | Address |
|----------|---------|
| Anchor | `0x7607af0cea78815c71bbea90110b2c218879354b` |

## DAO Configuration

| Contract | Parameter | Description | Default |
|----------|-----------|-------------|---------|
| **Anchor** | `eqtyFee` | EQTY amount burned per anchor | 0 |
| **Anchor** | `redeemContract` | Address to receive ETH payments | - |

## Design Philosophy

| Principle | Implementation |
|-----------|----------------|
| **Trustless** | No pause function, no admin backdoors |
| **Self-Correcting** | Rate adjusts automatically based on activity |
| **Deflationary** | EQTY burned on both Anchor and Redeem |
| **Real Yield** | ETH comes from actual protocol usage |
| **Minimal Governance** | Only Anchor is owner-controlled |

## Environment Variables

```bash
# Required for deployment
PRIVATE_KEY=            # Deployer private key
BASE_MAINNET_RPC_URL=   # Base mainnet RPC
BASE_SEPOLIA_RPC_URL=   # Base Sepolia RPC
BASESCAN_API_KEY=       # For contract verification

# Existing deployments / overrides
EQTY_TOKEN_ADDRESS=     # Optional: reuse an existing EQTY token
REDEEM_CONTRACT_ADDRESS=

# Configuration
BRIDGE_WALLET=          # Required if DeployRedeem should deploy EQTY on testnet
INITIAL_EXCHANGE_RATE=  # Required: initial ETH per redeem amount
REDEEM_AMOUNT=          # Required: EQTY burned on each redeem
MINT_DEADLINE=          # Optional: EQTY mint deadline when deployed from DeployRedeem
```

## Gas Optimization

All contracts are optimized for gas efficiency on Base L2:

- `via_ir` enabled for advanced optimizations
- 200 optimizer runs
- Minimal storage operations in Anchor (stateless design)
- Packed storage in Redeem (single slot for core config)
- Custom errors instead of require strings

## Security

| Contract | Security Features |
|----------|-------------------|
| **Anchor** | `Ownable2Step`, custom errors, max 100 anchors per tx |
| **EQTY** | Immutable bridge wallet, time-limited minting, 500M cap |
| **Redeem** | `ReentrancyGuard`, exact-output enforcement |

### Trust Model

- **No pause function** → Contracts cannot be stopped
- **No admin mint** → Supply is capped
- **Anchor replacement** → Redeem changes require deploying a new contract and repointing Anchor

## License

MIT
## Security

For security concerns, please contact: security@eqty.network
