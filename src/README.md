# RedeemEQTY Contract

Dynamic exchange rate redemption of EQTY tokens for ETH.

## Overview

```
                    ┌─────────────────┐
                    │   RedeemEQTY    │
                    │     Contract    │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ETH In (Anchor)      currentRate         ETH Out (Holders)
   ────────────►         Self-adjusts       ◄────────────
                           ±10% max
```

**Key Features:**

- 🔄 **Dynamic rate** - Adjusts gradually based on redemptions
- 🛡️ **Anti-frontrunning** - `minEthOut` slippage protection
- 📊 **Capped updates** - Max ±10% rate change per redeem
- 🔥 **Deflationary** - EQTY burned with optional foundation fee

## How It Works

### 1. ETH Flows In

Builders pay ETH via Anchor contract → ETH forwarded to RedeemEQTY

### 2. Rate Self-Adjusts

Every redeem updates the rate using a capped formula:

```math
r_next = r × clamp(p / r, 0.9, 1.1)
```

### 3. Holders Redeem

EQTY holders burn 10,000 EQTY → Receive ETH at current rate

## Usage

```solidity
// 1. Check expected output first
(uint256 ethOut, uint256 ethFee) = redeemContract.previewRedeem();

// 2. Approve EQTY spending
eqtyToken.approve(address(redeemContract), 10_000 ether);

// 3. Redeem with slippage protection
redeemContract.redeem(ethOut * 95 / 100); // Accept up to 5% slippage
```

**Slippage Protection:**

- Pass `minEthOut` to revert if you'd receive less
- Use `0` to accept any amount (not recommended for large amounts)

## Exchange Rate Mechanism

| Scenario | What Happens | Example |
|----------|--------------|---------|
| More ETH than rate | Rate increases (max +10%) | 0.01 → 0.011 |
| Less ETH than rate | Rate decreases (max -10%) | 0.01 → 0.009 |
| ETH equals rate | No change | 0.01 → 0.01 |

**Initial Rate:**
Owner sets at deployment. Calculate as:

```
rate = (EQTY_price × 10,000) / ETH_price
     = ($0.003 × 10,000) / $2,500
     = 0.012 ETH
```

After deployment, the rate self-adjusts based on actual activity.

## Owner Functions (DAO)

| Function | Description | Default |
|----------|-------------|---------|
| `setCurrentRate(uint256)` | Set/override exchange rate | Must be set initially |
| `setMaxRateChange(uint16)` | Max change per redeem (bps) | 1000 (10%) |
| `setRateBounds(min, max)` | Floor/ceiling safety | 0 / max |
| `setRedeemAmount(uint128)` | EQTY required per redeem | 10,000 |
| `setFoundationEthFee(uint16)` | ETH fee in bps | 0 |
| `setFoundationEqtyFee(uint16)` | EQTY fee in bps | 0 |
| `setFoundationWallet(address)` | Fee recipient | Treasury |

## Events

| Event | When Emitted |
|-------|--------------|
| `Redeemed(user, eqtyBurned, eqtyFee, ethReceived, ethFee, newRate)` | Successful redeem |
| `ETHReceived(from, amount)` | Contract receives ETH |
| `RateUpdated(oldRate, newRate)` | Rate changed |
| `MaxRateChangeUpdated(oldBps, newBps)` | Max change updated |
| `RateBoundsUpdated(oldMin, oldMax, newMin, newMax)` | Bounds updated |
| `FoundationEthFeeUpdated(oldFee, newFee)` | ETH fee changed |
| `FoundationEqtyFeeUpdated(oldFee, newFee)` | EQTY fee changed |

## Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `RateNotSet()` | currentRate is 0 | Owner must call `setCurrentRate()` |
| `InsufficientETH()` | No ETH in contract | Wait for more ETH or check `availableEth()` |
| `SlippageExceeded()` | Output < minEthOut | Lower `minEthOut` or call `previewRedeem()` |
| `InsufficientEQTYAllowance()` | User hasn't approved | Call `eqtyToken.approve()` |
| `InsufficientEQTYBalance()` | Not enough EQTY | Need 10,000 EQTY (default) |

## Security Design

| Feature | Purpose |
|---------|---------|
| **ReentrancyGuard** | Prevents reentrancy attacks |
| **Ownable2Step** | Two-step ownership transfer (secure DAO handoff) |
| **SafeERC20** | Safe token transfers |
| **Slippage protection** | `minEthOut` prevents frontrunning |
| **Rate bounds** | `minRate`/`maxRate` prevent extreme values |
| **CEI Pattern** | Checks-Effects-Interactions ordering |
| **No pause function** | Trustless - cannot be stopped |

## Known Addresses (Base)

| Contract | Address |
|----------|---------|
| EQTY Token | `0xC71F37D9bF4C5d1E7Fe4bCcB97e6f30B11b37D29` |
| Treasury | `0x2Bc456799F3Cf071B10CE7216269471e0A40381a` |

## Testing

```bash
# Run RedeemEQTY tests (40 tests)
forge test --match-contract RedeemEQTYTest -vvv

# Gas report
forge test --match-contract RedeemEQTYTest --gas-report
```

## Deployment

```bash
forge script script/DeployRedeem.s.sol:DeployRedeemEQTY \
  --rpc-url base_mainnet --broadcast --verify
```

**Post-Deployment Checklist:**

1. ✅ Set initial rate: `setCurrentRate(calculatedRate)`
2. ✅ Configure Anchor: `anchor.setRedeemContract(redeemAddress)`
3. ✅ Transfer to DAO: `transferOwnership(daoMultisig)`
4. ✅ DAO accepts: `acceptOwnership()`

## Related Contracts

| Contract | Relationship |
|----------|--------------|
| [EQTY.sol](./EQTY.sol) | Token that gets burned |
| [Anchor.sol](./Anchor.sol) | Sends ETH here via payments |
| [IRedeemEQTY.sol](./interfaces/IRedeemEQTY.sol) | Interface for integrations |
