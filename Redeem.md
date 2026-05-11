# Redeem Contract

Dynamic exchange rate redemption of EQTY tokens for ETH.

## Overview

```
                    ┌─────────────────┐
                    │     Redeem      │
                    │     Contract    │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ETH In (Anchor)     exchangeRate        ETH Out (Holders)
   ────────────►         Self-adjusts       ◄────────────
                           ±10% max
```

**Key Features:**

- 🔄 **Dynamic rate** - Adjusts gradually based on actual redemptions
- 🎯 **Exact output** - If `ethOut` is available, the caller receives exactly `ethOut`
- 📊 **Capped updates** - Max ±10% rate change per redeem
- 🔥 **Deflationary** - EQTY is burned on every redeem
- 💸 **Anchor fee quoting** - Converts EQTY-denominated anchor fees into ETH with a deployment-time premium

## How It Works

### 1. ETH Flows In

Builders pay ETH via Anchor contract → ETH forwarded to Redeem

When Anchor charges in ETH, it asks Redeem to quote the ETH price for the configured EQTY fee. The quote is:

```math
ethFee = (exchangeRate × eqtyFee / redeemAmount) × (1 + premium)
```

The premium is configured at deployment in basis points.

### 2. Redemption

EQTY holders burn the constructor-configured `redeemAmount` and request an exact ETH amount.

- If enough ETH is available, the contract pays exactly `ethOut`
- If not enough ETH is available, the transaction reverts

### 3. Rate Self-Adjusts

After a successful redeem, the rate updates using a capped formula based on the actual redeem payout:

```math
r_next = r × clamp(p / r, 0.9, 1.1)
```

## Usage

```solidity
// 1. Check the maximum redeemable amount first
(uint256 maxEthOut, uint256 ethFee) = redeemContract.previewRedeem();

// 2. Approve EQTY spending
eqtyToken.approve(address(redeemContract), redeemContract.redeemAmount());

// 3. Redeem for an exact net ETH output up to the available amount
redeemContract.redeem(0.1 ether);
```

## Exchange Rate Mechanism

| Scenario | What Happens | Example |
|----------|--------------|---------|
| Redeem payout above rate | Rate increases (max +10%) | 0.01 → 0.011 |
| Redeem payout below rate | Rate decreases (max -10%) | 0.01 → 0.009 |
| Redeem payout equals rate | No change | 0.01 → 0.01 |

The initial exchange rate, redeem amount, and anchor ETH premium are set in the constructor. After deployment, the exchange rate self-adjusts based on actual redemption activity.

## Events

| Event | When Emitted |
|-------|--------------|
| `Redeemed(user, eqtyBurned, eqtyFee, ethReceived, ethFee, newRate)` | Successful redeem |
| `ETHReceived(from, amount)` | Contract receives ETH |
| `ExchangeRateUpdated(oldExchangeRate, newExchangeRate)` | Exchange rate changed |

## Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `InsufficientETH()` | Not enough ETH is available for the requested redeem | Lower `ethOut` or wait for more ETH |
| `InsufficientEQTYAllowance()` | User hasn't approved | Call `eqtyToken.approve()` |
| `InsufficientEQTYBalance()` | Not enough EQTY | Need at least `redeemAmount()` EQTY |

## Security Design

| Feature | Purpose |
|---------|---------|
| **ReentrancyGuard** | Prevents reentrancy attacks |
| **Exact output enforcement** | Requested ETH is paid exactly or the transaction reverts |
| **CEI Pattern** | Checks-Effects-Interactions ordering |
| **No pause function** | Trustless - cannot be stopped |

## Known Addresses (Base)

| Contract | Address |
|----------|---------|
| EQTY Token | `0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29` |
| Treasury | `0x2Bc456799F3Cf071B10CE7216269471e0A40381a` |

## Testing

```bash
# Run Redeem tests
forge test --match-contract RedeemTest -vvv

# Gas report
forge test --match-contract RedeemTest --gas-report
```

## Deployment

```bash
forge script script/DeployRedeem.s.sol:DeployRedeem \
  --rpc-url base_mainnet --broadcast --verify
```

**Post-Deployment Checklist:**

1. ✅ Configure Anchor: `anchor.setRedeemContract(redeemAddress)`

## Related Contracts

| Contract | Relationship |
|----------|--------------|
| [EQTY.sol](./EQTY.sol) | Token that gets burned |
| [Anchor.sol](./Anchor.sol) | Sends ETH here via payments |
| [IRedeem.sol](./interfaces/IRedeem.sol) | Interface for integrations |
