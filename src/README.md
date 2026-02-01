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
| `setFoundationEthFee(uint16)` | ETH fee in bps (0-10000) | 0 |
| `setFoundationEqtyFee(uint16)` | EQTY fee in bps (0-10000) | 0 |
| `setFoundationWallet(address)` | Fee recipient | Treasury |

## Events

| Event | Description |
|-------|-------------|
| `Redemption(user, eqtyBurned, ethReceived)` | Emitted on successful redeem |
| `FoundationEthFeeUpdated(oldFee, newFee)` | ETH fee changed |
| `FoundationEqtyFeeUpdated(oldFee, newFee)` | EQTY fee changed |
| `RedeemAmountUpdated(oldAmount, newAmount)` | Redeem amount changed |
| `FoundationWalletUpdated(oldWallet, newWallet)` | Wallet changed |
| `FoundationEthWithdrawn(to, amount)` | ETH fees withdrawn |
| `FoundationEqtyWithdrawn(to, amount)` | EQTY fees withdrawn |

## Security

- **ReentrancyGuard** - Prevents reentrancy attacks
- **Ownable2Step** - Two-step ownership transfer (must call `acceptOwnership()`)
- **SafeERC20** - Safe token transfers with return value checking
- **Custom Errors** - Gas-efficient error handling
- **Storage Packing** - Optimized gas usage (uint128 + uint16)
- **CEI Pattern** - Checks-Effects-Interactions ordering

## Known Addresses (Base)

| Item | Address |
|------|---------|
| EQTY Token | `0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29` |
| Treasury | `0x2Bc456799F3Cf071B10CE7216269471e0A40381a` |

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

- [EQTY.sol](./EQTY.sol) - Token contract
- [Anchor.sol](./Anchor.sol) - Anchoring contract
