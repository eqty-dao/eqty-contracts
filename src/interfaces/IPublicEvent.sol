// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IPublicEvent
 * @notice Interface for canonical public events on Base
 * @dev Stateless contract surface for subject-specific event emission
 */
interface IPublicEvent {
    /**
     * @notice Emitted when a canonical public event is recorded for a subject
     * @param subjectId The subject identifier the event belongs to
     * @param source The caller that emitted the public event
     * @param eventType The human-readable application-defined event type
     * @param data Opaque event payload
     * @param timestamp The block timestamp when the event was emitted
     */
    event PublicEvent(
        bytes32 indexed subjectId,
        address indexed source,
        string eventType,
        bytes data,
        uint64 timestamp
    );

    /**
     * @notice Emit a canonical public event for a subject
     * @param subjectId The subject identifier the event belongs to
     * @param eventType The human-readable application-defined event type
     * @param data Opaque event payload
     * @dev Payment can be ETH (msg.value) or EQTY (burned from caller).
     */
    function emitPublicEvent(bytes32 subjectId, string calldata eventType, bytes calldata data) external payable;
}
