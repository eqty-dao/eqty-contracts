// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {Anchor} from "../src/Anchor.sol";
import {IAnchor} from "../src/interfaces/IAnchor.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockEQTY
 * @notice Mock EQTY token for Anchor testing
 */
contract MockEQTY is ERC20 {
    constructor() ERC20("EQTY", "EQTY") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}

contract AnchorTest is Test {
    Anchor public anchorContract;
    MockEQTY public eqtyToken;
    
    address public owner;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    uint256 public constant ANCHOR_FEE = 0.1 ether; // 0.1 EQTY per anchor
    
    function setUp() public {
        owner = address(this);
        eqtyToken = new MockEQTY();
        anchorContract = new Anchor();
        
        // Configure anchor contract
        anchorContract.setEqtyToken(address(eqtyToken));
        anchorContract.setAnchorFee(ANCHOR_FEE);
        
        // Give alice some EQTY tokens
        eqtyToken.mint(alice, 1000 ether);
    }
    
    // ============ Deployment Tests ============
    
    function test_constructor_setsOwner() public view {
        assertEq(anchorContract.owner(), owner);
    }
    
    function test_deployment_successful() public view {
        assertTrue(address(anchorContract) != address(0));
    }
    
    function test_initialState_noFeeConfigured() public {
        Anchor freshAnchor = new Anchor();
        assertEq(freshAnchor.anchorFee(), 0);
        assertEq(address(freshAnchor.eqtyToken()), address(0));
    }
    
    // ============ Fee Mechanism Tests ============
    
    function test_anchor_burnsEQTYAsFee() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);
        
        uint256 balanceBefore = eqtyToken.balanceOf(alice);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({
            key: keccak256("test-key"),
            value: keccak256("test-value")
        });
        
        anchorContract.anchor(anchors);
        
        assertEq(eqtyToken.balanceOf(alice), balanceBefore - ANCHOR_FEE);
        vm.stopPrank();
    }
    
    function test_setAnchorFee_onlyOwner() public {
        uint256 newFee = 0.5 ether;
        anchorContract.setAnchorFee(newFee);
        assertEq(anchorContract.anchorFee(), newFee);
    }
    
    function test_setAnchorFee_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        anchorContract.setAnchorFee(0.5 ether);
    }
    
    function test_setEqtyToken_onlyOwner() public {
        address newToken = makeAddr("newToken");
        anchorContract.setEqtyToken(newToken);
        assertEq(address(anchorContract.eqtyToken()), newToken);
    }
    
    function test_setEqtyToken_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        anchorContract.setEqtyToken(address(0));
    }
    
    function test_anchor_noFeeWhenZeroFee() public {
        anchorContract.setAnchorFee(0);
        
        vm.startPrank(alice);
        uint256 balanceBefore = eqtyToken.balanceOf(alice);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({
            key: keccak256("test-key"),
            value: keccak256("test-value")
        });
        
        anchorContract.anchor(anchors);
        
        assertEq(eqtyToken.balanceOf(alice), balanceBefore); // No tokens burned
        vm.stopPrank();
    }
    
    function test_anchor_noFeeWhenNoToken() public {
        anchorContract.setEqtyToken(address(0));
        
        vm.startPrank(alice);
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({
            key: keccak256("test-key"),
            value: keccak256("test-value")
        });
        
        // Should not revert even without token configured
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    // ============ Single Anchor Tests ============
    
    function test_anchor_emitsEvent() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);
        
        bytes32 key = keccak256("test-key");
        bytes32 value = keccak256("test-value");
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: key, value: value});
        
        vm.expectEmit(true, true, true, true);
        emit IAnchor.Anchored(key, value, alice, uint64(block.timestamp));
        
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    function test_anchor_withZeroValue() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);
        
        bytes32 key = keccak256("message-hash");
        bytes32 zeroValue = bytes32(0);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: key, value: zeroValue});
        
        vm.expectEmit(true, true, true, true);
        emit IAnchor.Anchored(key, zeroValue, alice, uint64(block.timestamp));
        
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    // ============ Batch Anchor Tests ============
    
    function test_anchor_batch10() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE * 10);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](10);
        for (uint256 i = 0; i < 10; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)),
                value: keccak256(abi.encodePacked("value-", i))
            });
        }
        
        uint256 balanceBefore = eqtyToken.balanceOf(alice);
        anchorContract.anchor(anchors);
        
        assertEq(eqtyToken.balanceOf(alice), balanceBefore - (ANCHOR_FEE * 10));
        vm.stopPrank();
    }
    
    function test_anchor_batch100() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE * 100);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](100);
        for (uint256 i = 0; i < 100; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)),
                value: keccak256(abi.encodePacked("value-", i))
            });
        }
        
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    function test_anchor_revertsTooManyAnchors() public {
        vm.startPrank(alice);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](101);
        for (uint256 i = 0; i < 101; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)),
                value: keccak256(abi.encodePacked("value-", i))
            });
        }
        
        vm.expectRevert("Too many anchors");
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    // ============ Edge Case Tests ============
    
    function test_anchor_emptyArray() public {
        vm.startPrank(alice);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](0);
        
        uint256 balanceBefore = eqtyToken.balanceOf(alice);
        anchorContract.anchor(anchors);
        
        assertEq(eqtyToken.balanceOf(alice), balanceBefore); // No fee charged
        vm.stopPrank();
    }
    
    function test_anchor_sameTimestampInBatch() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE * 5);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](5);
        for (uint256 i = 0; i < 5; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)),
                value: keccak256(abi.encodePacked("value-", i))
            });
        }
        
        // All events should have the same timestamp
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_anchor_arbitraryKeys(bytes32 key, bytes32 value) public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: key, value: value});
        
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    function testFuzz_anchor_batchSize(uint8 batchSize) public {
        vm.assume(batchSize <= 100);
        
        if (batchSize == 0) return;
        
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE * batchSize);
        
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](batchSize);
        for (uint256 i = 0; i < batchSize; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)),
                value: keccak256(abi.encodePacked("value-", i))
            });
        }
        
        anchorContract.anchor(anchors);
        vm.stopPrank();
    }
    
    // ============ Ownership Tests ============
    
    function test_transferOwnership_twoStep() public {
        address newOwner = makeAddr("newOwner");
        
        anchorContract.transferOwnership(newOwner);
        assertEq(anchorContract.owner(), owner); // Still old owner
        
        vm.prank(newOwner);
        anchorContract.acceptOwnership();
        assertEq(anchorContract.owner(), newOwner);
    }
}
