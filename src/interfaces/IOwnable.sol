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
        bool isLocked;              // DeFi collateral lock
        address lockedBy;           // Protocol that locked the token
        uint64 createdAt;           // Mint timestamp
    }

    struct ChainEvent {
        bytes32 previousHash;     // Hash of the previous event in the chain
        bytes32 eventHash;        // keccak256(previousHash, key, value, timestamp)
        string key;               // e.g., "metadata", "legal-contract", "transfer"
        string value;             // e.g., "ipfs://...", "0xOld->0xNew"
        uint64 timestamp;         // Block timestamp
    }

    // ============ Events ============
    
    /// @notice Emitted when a new Ownable is minted
    event OwnableMinted(
        uint256 indexed tokenId,
        address indexed creator,
        bytes32 contentHash,
        bool isPublic
    );

    /// @notice Emitted when a new event is added to the chain
    event OwnableEvent(
        uint256 indexed tokenId,
        bytes32 indexed previousHash,
        bytes32 indexed eventHash,
        string key,
        string value,
        uint64 timestamp
    );


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
        uint96 royaltyBps
    ) external payable returns (uint256 tokenId);

    /**
     * @notice Add a new event to the Ownable's event chain
     * @param tokenId The token to add the event to
     * @param key The event type or key
     * @param value The event payload or value
     */
    function addEvent(uint256 tokenId, string calldata key, string calldata value) external payable;


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
     * @notice Get event history for an Ownable
     * @param tokenId The token ID
     * @return Array of events
     */
    function getEventHistory(uint256 tokenId) external view returns (ChainEvent[] memory);
}
