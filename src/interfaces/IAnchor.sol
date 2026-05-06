// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAnchor
 * @notice Interface for the Anchor contract that records event chain hashes on Base
 * @dev Stateless contract that only emits events for off-chain indexing
 */
interface IAnchor {
    /**
     * @notice Struct representing an anchor entry
     * @param key The key (stateHash for chains, messageHash for messages)
     * @param value The value (eventHash for chains, 0x0 for messages)
     */
    struct Anchor {
        bytes32 key;
        bytes32 value;
    }

    /**
     * @notice Emitted when anchors are recorded
     * @param key The anchor key (indexed for filtering)
     * @param value The anchor value
     * @param sender The address that submitted the anchor (indexed)
     * @param timestamp The block timestamp when anchored
     */
    event Anchored(bytes32 indexed key, bytes32 value, address indexed sender, uint64 timestamp);

    /**
     * @notice Emitted when a canonical public event is recorded for a subject
     * @param subjectId The subject identifier the event belongs to
     * @param source The caller that emitted the public event
     * @param eventType The application-defined event type
     * @param data Opaque event payload
     * @param timestamp The block timestamp when the event was emitted
     */
    event PublicEvent(
        bytes32 indexed subjectId,
        address indexed source,
        bytes32 indexed eventType,
        bytes data,
        uint64 timestamp
    );

    /**
     * @notice Submit one or more anchors to be recorded on-chain
     * @param anchors Array of Anchor structs to record
     * @dev Emits an Anchored event for each anchor in the array.
     *      Payment can be ETH (msg.value) or EQTY (burned from caller).
     */
    function anchor(Anchor[] calldata anchors) external payable;

    /**
     * @notice Emit a canonical public event for a subject
     * @param subjectId The subject identifier the event belongs to
     * @param eventType The application-defined event type
     * @param data Opaque event payload
     * @dev Payment can be ETH (msg.value) or EQTY (burned from caller).
     */
    function emitPublicEvent(bytes32 subjectId, bytes32 eventType, bytes calldata data) external payable;
}
