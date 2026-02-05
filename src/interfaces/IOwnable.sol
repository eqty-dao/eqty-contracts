// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IOwnable
 * @notice Interface for the Ownable NFT contract
 * @dev Extends ERC-721 with anchoring, privacy controls, and DeFi locking
 */
interface IOwnable {
    // ============ Structs ============
    
    struct OwnableData {
        bytes32 contentHash;        // Hash of the ownable content
        string cid;                 // IPFS CID (private by default)
        address creator;            // Original minter
        uint96 royaltyBps;          // Royalty in basis points (100 = 1%)
        bool isPublic;              // Issuer-controlled visibility
        bool isLocked;              // DeFi collateral lock
        address lockedBy;           // Protocol that locked the token
        uint64 createdAt;           // Mint timestamp
    }

    // ============ Events ============
    
    /// @notice Emitted when a new Ownable is minted
    event OwnableMinted(
        uint256 indexed tokenId,
        address indexed creator,
        bytes32 contentHash,
        bool isPublic
    );

    /// @notice Emitted when an anchor is added to an Ownable
    event OwnableAnchored(
        uint256 indexed tokenId,
        bytes32 indexed hash,
        address indexed sender,
        uint64 timestamp
    );

    /// @notice Emitted when visibility is changed
    event VisibilityChanged(uint256 indexed tokenId, bool isPublic);

    /// @notice Emitted when an Ownable is locked
    event OwnableLocked(uint256 indexed tokenId, address indexed locker);

    /// @notice Emitted when an Ownable is unlocked
    event OwnableUnlocked(uint256 indexed tokenId);

    /// @notice Emitted when royalty is updated
    event RoyaltyUpdated(uint256 indexed tokenId, uint96 newRoyaltyBps);

    // ============ Errors ============
    
    error NotOwnerOrApproved();
    error NotCreator();
    error AlreadyLocked();
    error NotLocked();
    error NotLocker();
    error TokenLocked();
    error InvalidRoyalty();
    error ContentHashAlreadyMinted();
    error InsufficientPayment();

    // ============ Core Functions ============

    /**
     * @notice Mint a new Ownable NFT
     * @param contentHash Hash of the ownable content
     * @param cid IPFS CID for metadata
     * @param royaltyBps Royalty percentage in basis points
     * @param isPublic Whether metadata should be publicly visible
     * @return tokenId The ID of the newly minted token
     */
    function mint(
        bytes32 contentHash,
        string calldata cid,
        uint96 royaltyBps,
        bool isPublic
    ) external payable returns (uint256 tokenId);

    /**
     * @notice Anchor hashes to an Ownable
     * @param tokenId The token to anchor to
     * @param hashes Array of hashes to anchor
     */
    function anchor(uint256 tokenId, bytes32[] calldata hashes) external payable;

    /**
     * @notice Set the public visibility of an Ownable
     * @param tokenId The token ID
     * @param _isPublic New visibility setting
     */
    function setPublic(uint256 tokenId, bool _isPublic) external;

    /**
     * @notice Lock an Ownable for DeFi collateral
     * @param tokenId The token to lock
     */
    function lock(uint256 tokenId) external;

    /**
     * @notice Unlock an Ownable
     * @param tokenId The token to unlock
     */
    function unlock(uint256 tokenId) external;

    /**
     * @notice Check if an Ownable is locked
     * @param tokenId The token to check
     * @return Whether the token is locked
     */
    function isLocked(uint256 tokenId) external view returns (bool);

    /**
     * @notice Get Ownable data
     * @param tokenId The token ID
     * @return The OwnableData struct
     */
    function getOwnable(uint256 tokenId) external view returns (OwnableData memory);

    /**
     * @notice Get anchor history for an Ownable
     * @param tokenId The token ID
     * @return Array of anchored hashes
     */
    function getAnchorHistory(uint256 tokenId) external view returns (bytes32[] memory);
}
