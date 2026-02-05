# Ownable NFT Contract Specification

> **Status:** IMPLEMENTED  
> **Author:** Jan-martin  
> **Date:** 2026-02-04

## Overview

Merge Anchor.sol functionality with ERC-721 to create a unified **Ownable.sol** contract where each Ownable is an on-chain NFT with built-in anchoring and payment capabilities.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Ownable.sol                                │
│                   (ERC-721 + Anchoring + Payments)               │
│                                                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   ERC-721 NFT   │  │   Anchoring     │  │    Payments     │  │
│  │                 │  │                 │  │                 │  │
│  │ • mint()        │  │ • anchor()      │  │ • ETH → Redeem  │  │
│  │ • transfer()    │  │ • anchorMap     │  │ • EQTY burn     │  │
│  │ • ownerOf()     │  │ • verify()      │  │ • Fees config   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                   │
│  Events:                                                          │
│  • OwnableMinted(tokenId, creator, contentHash, cid)             │
│  • OwnableAnchored(tokenId, hash)                                │
│  • OwnableTransferred(tokenId, from, to)                         │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      RedeemEQTY.sol                               │
│                   (Unchanged - ETH Pool)                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## Marketplace Strategy

### 1. EQTY Own Marketplace (Primary)

- Custom UI tailored for Ownables
- Enhanced metadata display (events, history)
- Provenance visualization
- EQTY token rewards/discounts

### 2. OpenSea/External (Secondary)

- Automatic compatibility via ERC-721
- Standard metadata via `tokenURI()`
- Royalties via EIP-2981 (optional)

```
┌────────────────────────────────────────────────────────┐
│              EQTY Marketplace (ours)                   │
│  • Rich Ownable details                                │
│  • Event chain visualization                           │
│  • Direct EQTY/ETH payments                            │
│  • Creator royalties                                   │
└────────────────────────────────────────────────────────┘
                    ▲
                    │ (same NFTs)
                    ▼
┌────────────────────────────────────────────────────────┐
│              OpenSea / Blur / etc                      │
│  • Standard NFT listing                                │
│  • Basic metadata only                                 │
│  • Wider audience                                      │
└────────────────────────────────────────────────────────┘
```

---

## Contract Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title Ownable NFT Contract
 * @notice ERC-721 NFTs with built-in anchoring and provenance
 */
contract OwnableNFT is ERC721, ERC721URIStorage, ERC721Enumerable, IERC2981 {
    
    // ========================================
    // State
    // ========================================
    
    struct OwnableData {
        bytes32 contentHash;      // Hash of the ownable content
        string cid;               // IPFS CID
        uint256 createdAt;        // Timestamp
        address creator;          // Original creator
        bytes32[] anchorHistory;  // All anchored hashes
    }
    
    mapping(uint256 => OwnableData) public ownables;
    mapping(bytes32 => uint256) public hashToTokenId; // Lookup by hash
    
    address public redeemContract;
    uint256 public ethFee;
    uint256 public eqtyFee;
    
    uint256 private _nextTokenId;
    
    // ========================================
    // Events
    // ========================================
    
    event OwnableMinted(
        uint256 indexed tokenId,
        address indexed creator,
        bytes32 contentHash,
        string cid
    );
    
    event OwnableAnchored(
        uint256 indexed tokenId,
        bytes32 hash,
        uint256 timestamp
    );
    
    event PaymentReceived(
        uint256 indexed tokenId,
        address indexed payer,
        uint256 amount,
        bool isEth
    );
    
    // ========================================
    // Minting (Create Ownable)
    // ========================================
    
    /**
     * @notice Mint a new Ownable NFT
     * @param contentHash Hash of the ownable content
     * @param cid IPFS CID for metadata
     * @param metadataURI URI for OpenSea-compatible metadata
     */
    function mint(
        bytes32 contentHash,
        string calldata cid,
        string calldata metadataURI
    ) external payable returns (uint256) {
        require(hashToTokenId[contentHash] == 0, "Already minted");
        require(msg.value >= ethFee, "Insufficient ETH");
        
        // Forward ETH to RedeemEQTY
        if (msg.value > 0) {
            payable(redeemContract).transfer(msg.value);
        }
        
        uint256 tokenId = _nextTokenId++;
        
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURI);
        
        ownables[tokenId] = OwnableData({
            contentHash: contentHash,
            cid: cid,
            createdAt: block.timestamp,
            creator: msg.sender,
            anchorHistory: new bytes32[](0)
        });
        
        hashToTokenId[contentHash] = tokenId;
        
        emit OwnableMinted(tokenId, msg.sender, contentHash, cid);
        emit PaymentReceived(tokenId, msg.sender, msg.value, true);
        
        return tokenId;
    }
    
    // ========================================
    // Anchoring (Add provenance events)
    // ========================================
    
    /**
     * @notice Anchor additional hashes to an Ownable
     * @param tokenId The Ownable to anchor to
     * @param hashes Array of hashes to anchor
     */
    function anchor(
        uint256 tokenId,
        bytes32[] calldata hashes
    ) external payable {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(msg.value >= ethFee * hashes.length, "Insufficient ETH");
        
        if (msg.value > 0) {
            payable(redeemContract).transfer(msg.value);
        }
        
        for (uint i = 0; i < hashes.length; i++) {
            ownables[tokenId].anchorHistory.push(hashes[i]);
            emit OwnableAnchored(tokenId, hashes[i], block.timestamp);
        }
    }
    
    // ========================================
    // View Functions
    // ========================================
    
    /**
     * @notice Get all anchored hashes for an Ownable
     */
    function getAnchorHistory(uint256 tokenId) 
        external view returns (bytes32[] memory) 
    {
        return ownables[tokenId].anchorHistory;
    }
    
    /**
     * @notice Verify a hash exists in the anchor history
     */
    function verify(uint256 tokenId, bytes32 hash) 
        external view returns (bool, uint256 index) 
    {
        bytes32[] memory history = ownables[tokenId].anchorHistory;
        for (uint i = 0; i < history.length; i++) {
            if (history[i] == hash) {
                return (true, i);
            }
        }
        return (false, 0);
    }
    
    /**
     * @notice Get creator of an Ownable (for royalties)
     */
    function creatorOf(uint256 tokenId) external view returns (address) {
        return ownables[tokenId].creator;
    }
    
    // ========================================
    // EIP-2981 Royalties (OpenSea compatible)
    // ========================================
    
    uint256 public royaltyBps = 500; // 5%
    
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external view override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (
            ownables[tokenId].creator,
            (salePrice * royaltyBps) / 10000
        );
    }
    
    // ========================================
    // Required overrides
    // ========================================
    
    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721Enumerable, ERC721URIStorage, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId 
            || super.supportsInterface(interfaceId);
    }
    
    // ... additional required overrides
}
```

---

## Metadata Standard (OpenSea Compatible)

```json
{
  "name": "My Ownable #123",
  "description": "Provenance-tracked digital asset",
  "image": "ipfs://QmXxx.../preview.png",
  "external_url": "https://eqty.io/ownables/123",
  "attributes": [
    {
      "trait_type": "Creator",
      "value": "0x742d35..."
    },
    {
      "trait_type": "Created",
      "display_type": "date",
      "value": 1707012345
    },
    {
      "trait_type": "Anchor Count",
      "value": 5
    },
    {
      "trait_type": "Content Hash",
      "value": "0xabc123..."
    }
  ],
  "animation_url": "ipfs://QmXxx.../ownable.html"
}
```

---

## Migration Path

### Phase 1: Deploy new contract

- Deploy OwnableNFT.sol to Base
- Keep Anchor.sol running for backwards compatibility

### Phase 2: Migrate existing Ownables

- Mint NFTs for existing Ownables (admin function or user-claimed)
- Copy anchor history to on-chain storage

### Phase 3: Deprecate old system

- Update oBuilder to use new contract
- Deprecate old Anchor.sol

---

## Design Decisions

1. **Royalties:** Per-token configurable, max 10%, goes to creator
2. **Minting cost:** Dynamic ETH fee, configurable by admin
3. **Bulk operations:** Single mint per call (batch can be added later)
4. **Burning:** Not implemented (can be added if needed)
5. **Upgradability:** Non-upgradable for security
6. **Metadata hosting:** IPFS CID storage, visibility controlled by isPublic

---

## Implementation Status

- [x] OwnableNFT.sol implemented
- [x] 31 tests passing
- [x] eqty-core OwnableClient created
- [x] oBuilder EqtyService integration
- [ ] Deploy to Base Sepolia
- [ ] Security audit
