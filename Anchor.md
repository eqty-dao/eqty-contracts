# Anchor Contract

Stateless anchoring and canonical public event emission on Base.

## Overview

```
                    ┌─────────────────┐
                    │     Anchor      │
                    │    Contract     │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   Anchored events      PublicEvent logs     ETH -> Redeem
   (hash pairs)         (subject events)     EQTY -> burn
```

**Key Features:**

- Event-only storage for anchor data
- Two payment modes: forwarded ETH or burned EQTY
- Canonical `PublicEvent` emission for subject-specific integrations
- Neutral transport layer: records events but does not enforce subject semantics
- `Ownable2Step` admin model for fee and payment configuration

## How It Works

### 1. Generic anchoring

Call `anchor(Anchor[] calldata anchors)` to emit one or more `Anchored` events.

Typical uses:
- state hash chains
- message commitments
- off-chain replay checkpoints

### 2. Canonical public events

Call `emitPublicEvent(bytes32 subjectId, string calldata eventType, bytes calldata data)` to emit a canonical public event for a subject.

The Anchor contract records:
- `subjectId`
- `source`
- human-readable `eventType`
- opaque `data`
- `timestamp`

`source` is always the immediate caller (`msg.sender`).

## Two Usage Modes

`emitPublicEvent` can be used in two ways, depending on the Ownable implementation:

### 1. Contract-driven emission

An external contract calls Anchor as part of its own execution flow.

Example:

```solidity
function consume(bytes32 subjectId, bytes calldata data) external payable {
    anchor.emitPublicEvent{value: msg.value}(
        subjectId,
        "consume",
        data
    );
}
```

Behavior:
- `source` is the calling contract address
- the calling contract pays the fee
- the user can still fund that payment indirectly through the contract

### 2. Direct owner emission

The Ownable owner calls Anchor directly.

Example:

```solidity
eqty.approve(address(anchor), fee);
anchor.emitPublicEvent(
    subjectId,
    "manual_update",
    data
);
```

Behavior:
- `source` is the owner address
- the owner pays the fee directly

Which mode is valid is not decided by Anchor. The Ownable implementation decides whether it accepts:
- contract-only events
- owner-only events
- both

## Payment Model

The same payment model applies to both `anchor(...)` and `emitPublicEvent(...)`.

### Pay with ETH

Send ETH in the call:

```solidity
anchor.emitPublicEvent{value: fee}(subjectId, eventType, data);
```

Behavior:
- ETH is forwarded to `Redeem`
- the caller must send enough ETH in the same call
- native ETH has no allowance model

### Pay with EQTY

Approve Anchor to burn EQTY:

```solidity
eqty.approve(address(anchor), fee);
anchor.emitPublicEvent(subjectId, eventType, data);
```

Behavior:
- Anchor burns EQTY from the caller
- the caller must hold the EQTY and set the allowance

## Trust Model

Anchor does not decide whether an event is semantically valid for a subject.

That means:
- anyone can emit a `PublicEvent` if the call is otherwise valid
- a subject-specific implementation can ignore events from untrusted sources
- untrusted events are recorded on-chain but skipped during subject processing

This keeps Anchor simple and lets each subject implementation define its own trust rules.

## Key Functions

| Function | Purpose |
|----------|---------|
| `anchor(Anchor[] calldata)` | Emit one or more generic anchor events |
| `emitPublicEvent(bytes32, string, bytes)` | Emit one canonical public event |
| `getEthFee()` | Read current ETH fee per item |
| `previewEthCost(uint256)` | Read ETH cost for a batch size |
| `setEqtyFee(uint256)` | Set EQTY fee per item |
| `setEqtyToken(address)` | Set EQTY token contract |
| `setRedeemContract(address)` | Set Redeem contract for ETH forwarding |

## Events

| Event | When Emitted |
|-------|--------------|
| `Anchored(key, value, sender, timestamp)` | Generic anchoring |
| `PublicEvent(subjectId, source, eventType, data, timestamp)` | Canonical public event emission |
| `EqtyFeeUpdated(oldFee, newFee)` | EQTY fee updated |
| `EqtyTokenUpdated(oldToken, newToken)` | EQTY token updated |
| `RedeemContractUpdated(oldContract, newContract)` | Redeem address updated |
| `ETHForwarded(from, amount)` | ETH payment forwarded to Redeem |

## Related Contracts

| Contract | Relationship |
|----------|--------------|
| [Redeem.md](./Redeem.md) | Receives ETH payments from Anchor |
| [src/Anchor.sol](./src/Anchor.sol) | Contract implementation |
| [src/interfaces/IAnchor.sol](./src/interfaces/IAnchor.sol) | Interface for integrations |
