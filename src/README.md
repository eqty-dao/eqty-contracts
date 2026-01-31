# RedeemEQTY Contract

Burn EQTY tokens to receive ETH from Ownables fee payments.

## Overview

```
Ownables fees (ETH) → Contract → User burns EQTY → Receives ETH
```

- EQTY burned by default (deflationary)
- Optional fees (ETH + EQTY) for foundation (both default 0%)
- Gas-optimized with storage packing

## Usage

```solidity
// User approves EQTY spending
eqtyToken.approve(redeemContract, 10_000 ether);

// User redeems - burns EQTY, receives ETH
redeemContract.redeem();
```

## Owner Functions

| Function | Description | Default |
|----------|-------------|---------|
| `setRedeemAmount(uint128)` | EQTY required per redeem | 10,000 |
| `setFoundationEthFee(uint16)` | ETH fee in bps | 0 |
| `setFoundationEqtyFee(uint16)` | EQTY fee in bps | 0 |
| `setFoundationWallet(address)` | Fee recipient | Treasury |

## Testing (Foundry)

```bash
# Install Foundry deps
forge install

# Run tests
forge test -vvv
```

## Deployment

```bash
forge script script/DeployRedeem.s.sol:DeployRedeemEQTY \
  --rpc-url base_mainnet --broadcast --verify
```

## Related

- [EQTY.sol](../contracts/EQTY.sol) - Token contract
- [Anchor.sol](../contracts/Anchor.sol) - Anchoring contract
