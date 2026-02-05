// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./interfaces/IOwnable.sol";
import "./interfaces/IRedeemEQTY.sol";

/**
 * @title Ownable
 * @notice ERC-721 NFT contract for tokenized real-world assets with anchoring and privacy controls
 * @dev Key features:
 *      - Private by default: Issuer controls what is publicly visible
 *      - Integrated anchoring: Record provenance hashes directly on the NFT
 *      - DeFi-ready: lock()/unlock() for non-custodial collateralization (permissionless)
 *      - Flexible royalties: EIP-2981 compliant, configurable per token
 *      - Payment integration: ETH forwarded to RedeemEQTY contract
 *      - Emergency pause: Circuit breaker for security incidents
 *
 * @notice CID Encryption:
 *      For enterprise use, CIDs should be encrypted off-chain before storing.
 *      The contract stores the encrypted CID, and only authorized parties with
 *      the decryption key can access the actual content. This provides:
 *      - End-to-end encryption for sensitive RWA documents
 *      - Key rotation without on-chain changes
 *      - Selective disclosure through shared decryption keys
 *
 * @custom:security-contact security@eqty.network
 */
contract OwnableNFT is ERC721Enumerable, IERC2981, IOwnable, Ownable2Step, ReentrancyGuard, Pausable {
    // ============ State ============

    /// @notice Counter for token IDs
    uint256 private _tokenIdCounter;

    /// @notice Redeem contract for ETH payments
    IRedeemEQTY public redeemContract;

    /// @notice Fee per mint in ETH (based on redeem rate)
    uint256 public mintFeeMultiplier = 1; // Multiplier of base rate

    /// @notice Base URI for metadata
    string private _baseTokenURI;

    /// @notice Private placeholder URI for non-public tokens
    string public privateURI = "ipfs://private";

    /// @notice Ownable data for each token
    mapping(uint256 => OwnableData) private _ownables;

    /// @notice Anchor history for each token
    mapping(uint256 => bytes32[]) private _anchorHistory;

    /// @notice Mapping from content hash to token ID (prevents duplicates)
    mapping(bytes32 => uint256) public contentHashToTokenId;

    /// @notice Maximum royalty in basis points (10%)
    uint256 public constant MAX_ROYALTY_BPS = 1000;

    /// @notice Maximum anchors per transaction
    uint256 public constant MAX_ANCHORS_PER_TX = 100;

    // ============ Constructor ============

    /**
     * @notice Initialize the Ownable contract
     * @param name_ Token name
     * @param symbol_ Token symbol
     */
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        // Redeem contract can be set later by owner
    }

    // ============ Core Functions ============

    /**
     * @inheritdoc IOwnable
     */
    function mint(
        bytes32 contentHash,
        string calldata cid,  // Can be encrypted off-chain for enterprise privacy
        uint96 royaltyBps,
        bool isPublic
    ) external payable nonReentrant whenNotPaused returns (uint256 tokenId) {
        // Validate inputs
        if (contentHashToTokenId[contentHash] != 0) revert ContentHashAlreadyMinted();
        if (royaltyBps > MAX_ROYALTY_BPS) revert InvalidRoyalty();

        // Handle payment
        _handleMintPayment();

        // Increment and get token ID
        _tokenIdCounter++;
        tokenId = _tokenIdCounter;

        // Store ownable data
        _ownables[tokenId] = OwnableData({
            contentHash: contentHash,
            cid: cid,
            creator: msg.sender,
            royaltyBps: royaltyBps,
            isPublic: isPublic,
            isLocked: false,
            lockedBy: address(0),
            createdAt: uint64(block.timestamp)
        });

        // Map content hash to token ID
        contentHashToTokenId[contentHash] = tokenId;

        // Mint the token
        _safeMint(msg.sender, tokenId);

        emit OwnableMinted(tokenId, msg.sender, contentHash, isPublic);
    }

    /**
     * @inheritdoc IOwnable
     */
    function anchor(uint256 tokenId, bytes32[] calldata hashes) external payable nonReentrant whenNotPaused {
        _requireOwned(tokenId);
        if (!_isAuthorized(ownerOf(tokenId), msg.sender, tokenId)) revert NotOwnerOrApproved();
        if (hashes.length > MAX_ANCHORS_PER_TX) revert("Too many anchors");

        // Handle payment for anchoring
        _handleAnchorPayment(hashes.length);

        // Store anchors and emit events
        uint64 timestamp = uint64(block.timestamp);
        for (uint256 i = 0; i < hashes.length;) {
            _anchorHistory[tokenId].push(hashes[i]);
            emit OwnableAnchored(tokenId, hashes[i], msg.sender, timestamp);
            unchecked { ++i; }
        }
    }

    /**
     * @inheritdoc IOwnable
     */
    function setPublic(uint256 tokenId, bool _isPublic) external {
        OwnableData storage data = _ownables[tokenId];
        // Only creator can change visibility
        if (data.creator != msg.sender) revert NotCreator();

        data.isPublic = _isPublic;
        emit VisibilityChanged(tokenId, _isPublic);
    }

    /**
     * @notice Update royalty for a token (only creator)
     * @param tokenId The token ID
     * @param newRoyaltyBps New royalty in basis points
     */
    function setRoyalty(uint256 tokenId, uint96 newRoyaltyBps) external {
        OwnableData storage data = _ownables[tokenId];
        if (data.creator != msg.sender) revert NotCreator();
        if (newRoyaltyBps > MAX_ROYALTY_BPS) revert InvalidRoyalty();

        data.royaltyBps = newRoyaltyBps;
        emit RoyaltyUpdated(tokenId, newRoyaltyBps);
    }

    // ============ DeFi Locking ============

    /**
     * @inheritdoc IOwnable
     */
    function lock(uint256 tokenId) external {
        _requireOwned(tokenId);
        OwnableData storage data = _ownables[tokenId];
        
        // Only owner can initiate lock (locker is msg.sender - the protocol)
        if (ownerOf(tokenId) != msg.sender && !isApprovedForAll(ownerOf(tokenId), msg.sender)) {
            revert NotOwnerOrApproved();
        }
        if (data.isLocked) revert AlreadyLocked();

        data.isLocked = true;
        data.lockedBy = msg.sender;

        emit OwnableLocked(tokenId, msg.sender);
    }

    /**
     * @inheritdoc IOwnable
     */
    function unlock(uint256 tokenId) external {
        OwnableData storage data = _ownables[tokenId];
        if (!data.isLocked) revert NotLocked();
        if (data.lockedBy != msg.sender) revert NotLocker();

        data.isLocked = false;
        data.lockedBy = address(0);

        emit OwnableUnlocked(tokenId);
    }

    /**
     * @inheritdoc IOwnable
     */
    function isLocked(uint256 tokenId) external view returns (bool) {
        return _ownables[tokenId].isLocked;
    }

    // ============ View Functions ============

    /**
     * @inheritdoc IOwnable
     */
    function getOwnable(uint256 tokenId) external view returns (OwnableData memory) {
        _requireOwned(tokenId);
        return _ownables[tokenId];
    }

    /**
     * @inheritdoc IOwnable
     */
    function getAnchorHistory(uint256 tokenId) external view returns (bytes32[] memory) {
        return _anchorHistory[tokenId];
    }

    /**
     * @notice Get the CID only if caller is owner or token is public
     * @param tokenId The token ID
     * @return The CID or empty string
     */
    function getCid(uint256 tokenId) external view returns (string memory) {
        OwnableData storage data = _ownables[tokenId];
        if (data.isPublic || ownerOf(tokenId) == msg.sender) {
            return data.cid;
        }
        return "";
    }

    /**
     * @notice Verify a hash exists in the anchor history
     * @param tokenId The Ownable to check
     * @param hash The hash to search for
     * @return exists True if the hash is found
     * @return index The index of the hash in history (0 if not found)
     */
    function verify(uint256 tokenId, bytes32 hash) 
        external view returns (bool exists, uint256 index) 
    {
        bytes32[] storage history = _anchorHistory[tokenId];
        for (uint256 i = 0; i < history.length;) {
            if (history[i] == hash) {
                return (true, i);
            }
            unchecked { ++i; }
        }
        return (false, 0);
    }

    /**
     * @notice Get the original creator of an Ownable
     * @param tokenId The token ID
     * @return The creator address
     */
    function creatorOf(uint256 tokenId) external view returns (address) {
        return _ownables[tokenId].creator;
    }

    /**
     * @notice Returns the URI for a token
     * @dev Returns private placeholder if token is not public
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        OwnableData storage data = _ownables[tokenId];

        if (!data.isPublic) {
            return privateURI;
        }

        return string(abi.encodePacked(_baseTokenURI, data.cid));
    }

    // ============ EIP-2981 Royalties ============

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        OwnableData storage data = _ownables[tokenId];
        receiver = data.creator;
        royaltyAmount = (salePrice * data.royaltyBps) / 10000;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ============ Internal Functions ============

    /**
     * @notice Handle payment for minting
     */
    function _handleMintPayment() internal {
        if (address(redeemContract) == address(0)) return; // Free if no redeem set

        uint256 rate = redeemContract.currentRate();
        uint256 requiredEth = rate * mintFeeMultiplier;

        if (msg.value < requiredEth) revert InsufficientPayment();

        // Forward ETH to Redeem contract
        if (msg.value > 0) {
            (bool success,) = address(redeemContract).call{value: msg.value}("");
            require(success, "ETH transfer failed");
        }
    }

    /**
     * @notice Handle payment for anchoring
     * @param numAnchors Number of anchors
     */
    function _handleAnchorPayment(uint256 numAnchors) internal {
        if (address(redeemContract) == address(0)) return;

        uint256 rate = redeemContract.currentRate();
        uint256 requiredEth = rate * numAnchors;

        if (msg.value < requiredEth) revert InsufficientPayment();

        if (msg.value > 0) {
            (bool success,) = address(redeemContract).call{value: msg.value}("");
            require(success, "ETH transfer failed");
        }
    }

    /**
     * @dev Override to prevent transfers of locked tokens
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override
        returns (address)
    {
        // Check if token is locked (skip for minting when from is 0)
        if (_ownerOf(tokenId) != address(0) && _ownables[tokenId].isLocked) {
            revert TokenLocked();
        }
        return super._update(to, tokenId, auth);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the Redeem contract address
     * @param _redeemContract New Redeem contract
     */
    function setRedeemContract(address _redeemContract) external onlyOwner {
        redeemContract = IRedeemEQTY(_redeemContract);
    }

    /**
     * @notice Set the mint fee multiplier
     * @param _multiplier New multiplier
     */
    function setMintFeeMultiplier(uint256 _multiplier) external onlyOwner {
        mintFeeMultiplier = _multiplier;
    }

    /**
     * @notice Set the base URI for tokens
     * @param baseURI_ New base URI
     */
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    /**
     * @notice Set the private placeholder URI
     * @param _privateURI New private URI
     */
    function setPrivateURI(string calldata _privateURI) external onlyOwner {
        privateURI = _privateURI;
    }

    // ============ Emergency Controls ============

    /**
     * @notice Pause the contract in case of emergency
     * @dev Only owner (DAO) can pause. Prevents minting and anchoring.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract
     * @dev Only owner (DAO) can unpause.
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
