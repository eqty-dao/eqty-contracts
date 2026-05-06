// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IAnchor.sol";
import "./interfaces/IRedeemEQTY.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEQTY is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title Anchor
 * @notice Lightweight anchoring contract for recording event chain hashes on Base
 * @dev This contract is completely stateless for anchoring - all data is recorded via events only.
 *      The only storage used is for the fee configuration, EQTY token address, and Redeem contract.
 *      This design choice provides ~90% gas savings compared to storage-based approaches
 *      while maintaining full auditability through indexed events.
 *
 * Payment options:
 * - ETH: Sent to Redeem contract (price based on currentRate)
 * - EQTY: Burned (deflationary, DAO-configurable amount)
 *
 * Canonical public events can also be emitted for subject-specific integrations.
 *
 * @custom:security-contact security@eqty.network
 */
contract Anchor is IAnchor, Ownable2Step {
    /// @notice The EQTY token used for fee payments
    IEQTY public eqtyToken;

    /// @notice The Redeem contract that receives ETH and provides rate
    IRedeemEQTY public redeemContract;

    /// @notice Fee amount in EQTY tokens per anchor (DAO-configurable)
    uint256 public eqtyFee;

    /// @notice Maximum number of anchors allowed in a single transaction
    uint256 public constant MAX_ANCHORS_PER_TX = 100;

    // ============ Events ============

    /// @notice Emitted when the EQTY fee is updated
    event EqtyFeeUpdated(uint256 oldFee, uint256 newFee);

    /// @notice Emitted when the EQTY token address is updated
    event EqtyTokenUpdated(address indexed oldToken, address indexed newToken);

    /// @notice Emitted when the Redeem contract address is updated
    event RedeemContractUpdated(address indexed oldContract, address indexed newContract);

    /// @notice Emitted when ETH is forwarded to Redeem contract
    event ETHForwarded(address indexed from, uint256 amount);

    // ============ Errors ============

    error InsufficientETH();
    error InvalidAddress();
    error RedeemContractNotSet();
    error ETHTransferFailed();
    error TooManyAnchors();

    /**
     * @notice Constructor sets the deployer as the owner
     * @dev EQTY token, Redeem contract, and fee can be configured later by the owner
     */
    constructor() Ownable(msg.sender) {
        // Token, Redeem contract, and fee will be set by owner after deployment
    }

    /**
     * @notice Submit one or more anchors to be recorded on-chain
     * @param anchors Array of Anchor structs containing key-value pairs to record
     * @dev Payment options:
     *      1. Send ETH (msg.value > 0): ETH forwarded to Redeem contract
     *      2. No ETH (msg.value == 0): EQTY burned from caller
     *
     * Requirements:
     * - If paying with ETH: msg.value must cover the fee based on currentRate
     * - If paying with EQTY: Caller must have approved this contract to burn tokens
     *
     * Common usage patterns:
     * - Event chains: key = stateHash, value = eventHash
     * - Messages: key = messageHash, value = 0x0
     */
    function anchor(Anchor[] calldata anchors) external payable override {
        uint256 anchorsLength = anchors.length;
        if (anchorsLength > MAX_ANCHORS_PER_TX) revert TooManyAnchors();

        _collectPayment(anchorsLength);

        // Cache timestamp once to save gas on multiple anchors
        uint64 timestamp = uint64(block.timestamp);

        // Emit an event for each anchor
        for (uint256 i = 0; i < anchorsLength;) {
            emit Anchored(anchors[i].key, anchors[i].value, msg.sender, timestamp);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Emit a canonical public event for a subject
     * @param subjectId The subject identifier the event belongs to
     * @param eventType The application-defined event type
     * @param data Opaque event payload
     * @dev Uses the same ETH-or-EQTY payment model as generic anchoring.
     */
    function emitPublicEvent(
        bytes32 subjectId,
        bytes32 eventType,
        bytes calldata data
    ) external payable override {
        _collectPayment(1);

        emit PublicEvent(subjectId, msg.sender, eventType, data, uint64(block.timestamp));
    }

    /**
     * @notice Get the current ETH fee per anchor based on Redeem contract rate
     * @return ETH amount required per anchor
     */
    function getEthFee() external view returns (uint256) {
        if (address(redeemContract) == address(0)) return 0;
        return redeemContract.currentRate();
    }

    /**
     * @notice Preview total ETH cost for a batch of anchors
     * @param numAnchors Number of anchors to submit
     * @return Total ETH required
     */
    function previewEthCost(uint256 numAnchors) external view returns (uint256) {
        if (address(redeemContract) == address(0)) return 0;
        return redeemContract.currentRate() * numAnchors;
    }

    // ============ Internal Functions ============

    /**
     * @notice Collect payment using the same logic for anchors and public events
     * @param count Number of billable items being submitted
     */
    function _collectPayment(uint256 count) internal {
        if (count == 0) return;

        if (msg.value > 0) {
            _handleEthPayment(count);
        } else if (eqtyFee > 0 && address(eqtyToken) != address(0)) {
            eqtyToken.burnFrom(msg.sender, eqtyFee * count);
        }
    }

    /**
     * @notice Handle ETH payment by forwarding to Redeem contract
     * @param count Number of billable items being submitted
     */
    function _handleEthPayment(uint256 count) internal {
        if (address(redeemContract) == address(0)) revert RedeemContractNotSet();

        // Get current rate from Redeem contract
        uint256 rate = redeemContract.currentRate();
        uint256 requiredEth = rate * count;

        if (msg.value < requiredEth) revert InsufficientETH();

        // Forward ETH to Redeem contract
        (bool success,) = address(redeemContract).call{value: msg.value}("");
        if (!success) revert ETHTransferFailed();

        emit ETHForwarded(msg.sender, msg.value);
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the EQTY fee per anchor
     * @param newFee New fee amount in EQTY tokens (wei)
     * @dev Only callable by owner (DAO). Emits EqtyFeeUpdated event.
     */
    function setEqtyFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = eqtyFee;
        eqtyFee = newFee;
        emit EqtyFeeUpdated(oldFee, newFee);
    }

    /**
     * @notice Update the EQTY token address
     * @param newEqtyToken New EQTY token address (can be address(0) to disable EQTY fees)
     * @dev Only callable by owner. Emits EqtyTokenUpdated event.
     */
    function setEqtyToken(address newEqtyToken) external onlyOwner {
        address oldToken = address(eqtyToken);
        eqtyToken = IEQTY(newEqtyToken);
        emit EqtyTokenUpdated(oldToken, newEqtyToken);
    }

    /**
     * @notice Update the Redeem contract address
     * @param newRedeemContract New Redeem contract address
     * @dev Only callable by owner. Emits RedeemContractUpdated event.
     *      Setting to address(0) disables ETH payments.
     */
    function setRedeemContract(address newRedeemContract) external onlyOwner {
        address oldContract = address(redeemContract);
        redeemContract = IRedeemEQTY(newRedeemContract);
        emit RedeemContractUpdated(oldContract, newRedeemContract);
    }
}
