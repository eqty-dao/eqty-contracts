// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/OwnableNFT.sol";
import "../src/RedeemEQTY.sol";
import "../src/EQTY.sol";

contract OwnableNFTTest is Test {
    OwnableNFT public ownable;
    RedeemEQTY public redeem;
    EQTY public eqty;

    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public protocol = address(0x3);

    bytes32 constant CONTENT_HASH = keccak256("test-content");
    string constant CID = "QmTest123";

    function setUp() public {
        // Deploy EQTY token
        eqty = new EQTY(owner, block.timestamp + 365 days);

        // Deploy Redeem contract
        redeem = new RedeemEQTY(address(eqty), owner);

        // Deploy Ownable contract
        ownable = new OwnableNFT("EQTY Ownables", "OWN");
        ownable.setRedeemContract(address(redeem));
        ownable.setBaseURI("ipfs://");

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(protocol, 100 ether);
    }

    // ============ Minting Tests ============

    function test_Mint_Success() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        uint256 expectedTokenId = uint256(keccak256(abi.encodePacked(alice, CONTENT_HASH)));
        assertEq(tokenId, expectedTokenId);
        assertEq(ownable.ownerOf(tokenId), alice);
        
        IOwnable.OwnableData memory data = ownable.getOwnable(tokenId);
        assertEq(data.contentHash, CONTENT_HASH);
        assertEq(data.creator, alice);
        assertEq(data.royaltyBps, 500);
        assertEq(data.isLocked, false);
    }

    function test_Mint_DuplicateContentHash_Reverts() public {
        vm.prank(alice);
        ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(bob);
        vm.expectRevert(IOwnable.ContentHashAlreadyMinted.selector);
        ownable.mint{value: 0}(CONTENT_HASH, "Other", 500);
    }

    function test_Mint_InvalidRoyalty_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(IOwnable.InvalidRoyalty.selector);
        ownable.mint{value: 0}(CONTENT_HASH, CID, 1001); // > 10%
    }

    function test_TokenURI() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        string memory uri = ownable.tokenURI(tokenId);
        assertEq(uri, string(abi.encodePacked("ipfs://", CID)));
    }

    // ============ Event Chain Tests ============

    function test_AddEvent_ByOwner() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.addEvent(tokenId, "metadata", "ipfs://new-uri");

        IOwnable.ChainEvent[] memory history = ownable.getEventHistory(tokenId);
        
        // init + metadata = 2 events
        assertEq(history.length, 2);
        
        assertEq(history[0].key, "init");
        assertEq(history[0].value, string(abi.encodePacked("cid:", CID)));
        assertEq(history[0].previousHash, bytes32(0)); // Genesis previous hash is 0
        
        assertEq(history[1].key, "metadata");
        assertEq(history[1].value, "ipfs://new-uri");
        assertEq(history[1].previousHash, history[0].eventHash); // Chain links correctly
    }

    function test_AddEvent_NotOwner_Reverts() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(bob);
        vm.expectRevert(IOwnable.NotOwnerOrApproved.selector);
        ownable.addEvent(tokenId, "metadata", "ipfs://new-uri");
    }

    function test_ImplicitTransferEvent() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.transferFrom(alice, bob, tokenId);

        IOwnable.ChainEvent[] memory history = ownable.getEventHistory(tokenId);
        
        // init + transfer = 2 events
        assertEq(history.length, 2);
        assertEq(history[1].key, "transfer");
        
        // The value should contain both addresses based on Strings.toHexString
        assertEq(ownable.ownerOf(tokenId), bob);
    }

    function test_CreatorOf() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        assertEq(ownable.creatorOf(tokenId), alice);

        // Transfer doesn't change creator
        vm.prank(alice);
        ownable.transferFrom(alice, bob, tokenId);

        assertEq(ownable.creatorOf(tokenId), alice); // Still original creator
    }
    // ============ Locking Tests ============

    function test_Lock_ByOwner() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        assertEq(ownable.isLocked(tokenId), false);

        vm.prank(alice);
        ownable.lock(tokenId);

        assertEq(ownable.isLocked(tokenId), true);
    }

    function test_Lock_Twice_Reverts() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.lock(tokenId);

        vm.prank(alice);
        vm.expectRevert(IOwnable.AlreadyLocked.selector);
        ownable.lock(tokenId);
    }

    function test_Unlock_ByLocker() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.lock(tokenId);

        vm.prank(alice);
        ownable.unlock(tokenId);

        assertEq(ownable.isLocked(tokenId), false);
    }

    function test_Unlock_NotLocker_Reverts() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.lock(tokenId);

        vm.prank(bob);
        vm.expectRevert(IOwnable.NotLocker.selector);
        ownable.unlock(tokenId);
    }

    function test_Transfer_Locked_Reverts() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.lock(tokenId);

        vm.prank(alice);
        vm.expectRevert(IOwnable.TokenLocked.selector);
        ownable.transferFrom(alice, bob, tokenId);
    }

    function test_Transfer_Unlocked_Success() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.transferFrom(alice, bob, tokenId);

        assertEq(ownable.ownerOf(tokenId), bob);
    }

    // ============ Royalty Tests ============

    function test_RoyaltyInfo() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        (address receiver, uint256 royalty) = ownable.royaltyInfo(tokenId, 1 ether);

        assertEq(receiver, alice);
        assertEq(royalty, 0.05 ether); // 5% of 1 ether
    }

    function test_SetRoyalty_ByCreator() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(alice);
        ownable.setRoyalty(tokenId, 300);

        (address receiver, uint256 royalty) = ownable.royaltyInfo(tokenId, 1 ether);
        assertEq(royalty, 0.03 ether); // 3% of 1 ether
    }

    function test_SetRoyalty_NotCreator_Reverts() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        vm.prank(bob);
        vm.expectRevert(IOwnable.NotCreator.selector);
        ownable.setRoyalty(tokenId, 300);
    }

    // ============ Interface Support Tests ============

    function test_SupportsInterface_ERC721() public view {
        assertTrue(ownable.supportsInterface(type(IERC721).interfaceId));
    }

    function test_SupportsInterface_ERC2981() public view {
        assertTrue(ownable.supportsInterface(type(IERC2981).interfaceId));
    }

    // ============ Admin Tests ============

    function test_SetBaseURI() public {
        ownable.setBaseURI("https://api.eqty.network/");
        
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        string memory uri = ownable.tokenURI(tokenId);
        assertEq(uri, string(abi.encodePacked("https://api.eqty.network/", CID)));
    }

    // ============ Pause Tests ============

    function test_Pause_ByOwner() public {
        ownable.pause();
        assertTrue(ownable.paused());
    }

    function test_Pause_NotOwner_Reverts() public {
        vm.prank(alice);
        vm.expectRevert();
        ownable.pause();
    }

    function test_Mint_WhenPaused_Reverts() public {
        ownable.pause();

        vm.prank(alice);
        vm.expectRevert();
        ownable.mint{value: 0}(CONTENT_HASH, CID, 500);
    }

    function test_AddEvent_WhenPaused_Reverts() public {
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        ownable.pause();

        vm.prank(alice);
        vm.expectRevert();
        ownable.addEvent(tokenId, "k", "v");
    }

    function test_Unpause() public {
        ownable.pause();
        assertTrue(ownable.paused());
        
        ownable.unpause();
        assertFalse(ownable.paused());

        // Should work after unpause
        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);
        uint256 expectedTokenId = uint256(keccak256(abi.encodePacked(alice, CONTENT_HASH)));
        assertEq(tokenId, expectedTokenId);
    }

    function test_SetPrivateURI() public {
        ownable.setPrivateURI("ipfs://hidden");

        vm.prank(alice);
        uint256 tokenId = ownable.mint{value: 0}(CONTENT_HASH, CID, 500);

        string memory uri = ownable.tokenURI(tokenId);
        assertEq(uri, "ipfs://hidden");
    }
}
