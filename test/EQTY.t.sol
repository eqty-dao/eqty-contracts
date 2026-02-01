// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {EQTY} from "../src/EQTY.sol";

contract EQTYTest is Test {
    EQTY public eqtyToken;
    
    address public bridgeWallet = makeAddr("bridge");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    uint256 public constant TOTAL_SUPPLY = 500_000_000 ether;
    uint256 public mintDeadline;
    
    function setUp() public {
        mintDeadline = block.timestamp + 365 days;
        eqtyToken = new EQTY(bridgeWallet, mintDeadline);
    }
    
    // ============ Constructor Tests ============
    
    function test_constructor_setsValues() public view {
        assertEq(eqtyToken.name(), "EQTY");
        assertEq(eqtyToken.symbol(), "EQTY");
        assertEq(eqtyToken.bridgeWallet(), bridgeWallet);
        assertEq(eqtyToken.mintDeadline(), mintDeadline);
        assertEq(eqtyToken.cap(), TOTAL_SUPPLY);
    }
    
    function test_constructor_revertsZeroBridgeWallet() public {
        vm.expectRevert(EQTY.InvalidBridgeWallet.selector);
        new EQTY(address(0), mintDeadline);
    }
    
    function test_constructor_revertsDeadlineInPast() public {
        vm.expectRevert(EQTY.DeadlineMustBeInFuture.selector);
        new EQTY(bridgeWallet, block.timestamp);
    }
    
    // ============ Minting Tests ============
    
    function test_mint_onlyBridgeWallet() public {
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        assertEq(eqtyToken.balanceOf(alice), 1000 ether);
    }
    
    function test_mint_revertsForNonBridge() public {
        vm.prank(alice);
        vm.expectRevert(EQTY.NotBridgeWallet.selector);
        eqtyToken.mint(alice, 1000 ether);
    }
    
    function test_mint_revertsAfterDeadline() public {
        vm.warp(mintDeadline + 1);
        
        vm.prank(bridgeWallet);
        vm.expectRevert(EQTY.MintingPeriodExpired.selector);
        eqtyToken.mint(alice, 1000 ether);
    }
    
    function test_mint_worksAtDeadline() public {
        vm.warp(mintDeadline);
        
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        assertEq(eqtyToken.balanceOf(alice), 1000 ether);
    }
    
    function test_mint_emitsBridgeMintEvent() public {
        vm.prank(bridgeWallet);
        
        vm.expectEmit(true, false, false, true);
        emit EQTY.BridgeMint(alice, 1000 ether);
        
        eqtyToken.mint(alice, 1000 ether);
    }
    
    function test_mint_respectsCap() public {
        vm.startPrank(bridgeWallet);
        
        // Mint up to cap
        eqtyToken.mint(alice, TOTAL_SUPPLY);
        
        // Try to mint more - should revert
        vm.expectRevert();
        eqtyToken.mint(alice, 1);
        
        vm.stopPrank();
    }
    
    // ============ Transfer Tests ============
    
    function test_transfer_works() public {
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        vm.prank(alice);
        eqtyToken.transfer(bob, 500 ether);
        
        assertEq(eqtyToken.balanceOf(alice), 500 ether);
        assertEq(eqtyToken.balanceOf(bob), 500 ether);
    }
    
    function test_approve_and_transferFrom() public {
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        vm.prank(alice);
        eqtyToken.approve(bob, 500 ether);
        
        vm.prank(bob);
        eqtyToken.transferFrom(alice, bob, 500 ether);
        
        assertEq(eqtyToken.balanceOf(alice), 500 ether);
        assertEq(eqtyToken.balanceOf(bob), 500 ether);
    }
    
    // ============ Burn Tests ============
    
    function test_burn_works() public {
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        vm.prank(alice);
        eqtyToken.burn(500 ether);
        
        assertEq(eqtyToken.balanceOf(alice), 500 ether);
        assertEq(eqtyToken.totalSupply(), 500 ether);
    }
    
    function test_burnFrom_withApproval() public {
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        vm.prank(alice);
        eqtyToken.approve(bob, 500 ether);
        
        vm.prank(bob);
        eqtyToken.burnFrom(alice, 500 ether);
        
        assertEq(eqtyToken.balanceOf(alice), 500 ether);
        assertEq(eqtyToken.totalSupply(), 500 ether);
    }
    
    function test_burnFrom_revertsWithoutApproval() public {
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        vm.prank(bob);
        vm.expectRevert();
        eqtyToken.burnFrom(alice, 500 ether);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_mint_respectsCap(uint256 amount) public {
        vm.assume(amount <= TOTAL_SUPPLY);
        
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, amount);
        
        assertEq(eqtyToken.balanceOf(alice), amount);
    }
    
    function testFuzz_transfer_works(uint256 amount) public {
        vm.assume(amount <= 1000 ether);
        
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, 1000 ether);
        
        vm.prank(alice);
        eqtyToken.transfer(bob, amount);
        
        assertEq(eqtyToken.balanceOf(bob), amount);
    }
    
    function testFuzz_burn_reducesSupply(uint256 burnAmount) public {
        uint256 mintAmount = 1000 ether;
        vm.assume(burnAmount <= mintAmount);
        
        vm.prank(bridgeWallet);
        eqtyToken.mint(alice, mintAmount);
        
        vm.prank(alice);
        eqtyToken.burn(burnAmount);
        
        assertEq(eqtyToken.totalSupply(), mintAmount - burnAmount);
    }
}
