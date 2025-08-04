// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IAnchor.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEQTY is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title Anchor
 * @notice Lightweight anchoring contract for recording event chain hashes on Base
 * @dev This contract is completely stateless for anchoring - all data is recorded via events only.
 *      The only storage used is for the fee configuration and EQTY token address.
 *      This design choice provides ~90% gas savings compared to storage-based approaches
 *      while maintaining full auditability through indexed events.
 * 
 * @custom:security-contact security@eqty.network
 */
contract Anchor is IAnchor, Ownable2Step {
    /// @notice The EQTY token used for fee payments
    IEQTY public eqtyToken;
    
    /// @notice Fee amount in EQTY tokens per anchor
    uint256 public anchorFee;
    
    /// @notice Maximum number of anchors allowed in a single transaction
    uint256 public constant MAX_ANCHORS_PER_TX = 100;
    
    /// @notice Emitted when the anchor fee is updated
    event AnchorFeeUpdated(uint256 oldFee, uint256 newFee);
    
    /// @notice Emitted when the EQTY token address is updated
    event EqtyTokenUpdated(address indexed oldToken, address indexed newToken);
    
    /**
     * @notice Constructor sets the deployer as the owner
     * @dev EQTY token and fee can be configured later by the owner
     */
    constructor() Ownable(msg.sender) {
        // Token and fee will be set by owner after deployment
    }
    /**
     * @notice Submit one or more anchors to be recorded on-chain
     * @param anchors Array of Anchor structs containing key-value pairs to record
     * @dev This function burns EQTY tokens as payment for anchoring.
     *      Each anchor in the array will emit a separate Anchored event.
     *      The function is optimized for gas efficiency with minimal storage operations.
     * 
     * Requirements:
     * - Caller must have approved this contract to burn their EQTY tokens
     * - Caller must have sufficient EQTY balance for all anchors
     * 
     * Common usage patterns:
     * - Event chains: key = stateHash, value = eventHash
     * - Messages: key = messageHash, value = 0x0
     */
    function anchor(Anchor[] calldata anchors) external override {
        uint256 anchorsLength = anchors.length;
        require(anchorsLength <= MAX_ANCHORS_PER_TX, "Too many anchors");
        
        // Calculate total fee and burn tokens
        if (anchorsLength > 0 && anchorFee > 0 && address(eqtyToken) != address(0)) {
            uint256 totalFee = anchorFee * anchorsLength;
            eqtyToken.burnFrom(msg.sender, totalFee);
        }
        
        // Cache timestamp once to save gas on multiple anchors
        uint64 timestamp = uint64(block.timestamp);
        
        // Emit an event for each anchor
        for (uint256 i = 0; i < anchorsLength; ) {
            emit Anchored(
                anchors[i].key,
                anchors[i].value,
                msg.sender,
                timestamp
            );
            
            unchecked {
                ++i;
            }
        }
    }
    
    /**
     * @notice Update the fee per anchor
     * @param newFee New fee amount in EQTY tokens (wei)
     * @dev Only callable by owner. Emits AnchorFeeUpdated event.
     */
    function setAnchorFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = anchorFee;
        anchorFee = newFee;
        emit AnchorFeeUpdated(oldFee, newFee);
    }
    
    /**
     * @notice Update the EQTY token address
     * @param newEqtyToken New EQTY token address (can be address(0) to disable fees)
     * @dev Only callable by owner. Emits EqtyTokenUpdated event.
     */
    function setEqtyToken(address newEqtyToken) external onlyOwner {
        address oldToken = address(eqtyToken);
        eqtyToken = IEQTY(newEqtyToken);
        emit EqtyTokenUpdated(oldToken, newEqtyToken);
    }
}