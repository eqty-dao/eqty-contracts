// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {RedeemEQTY, IEQTY} from "../../src/RedeemEQTY.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockEQTY
 * @notice Mock EQTY token for testing
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

contract RedeemEQTYTest is Test {
    RedeemEQTY public redeemContract;
    MockEQTY public eqtyToken;
    
    address public foundation = makeAddr("foundation");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    uint128 public constant REDEEM_AMOUNT = 10_000 ether;
    
    function setUp() public {
        eqtyToken = new MockEQTY();
        redeemContract = new RedeemEQTY(address(eqtyToken), foundation);
        eqtyToken.mint(alice, uint256(REDEEM_AMOUNT) * 10);
        vm.deal(address(redeemContract), 10 ether);
    }
    
    // ============ Constructor Tests ============
    
    function test_constructor_setsValues() public view {
        assertEq(address(redeemContract.eqtyToken()), address(eqtyToken));
        assertEq(redeemContract.foundationWallet(), foundation);
        assertEq(redeemContract.owner(), address(this));
        assertEq(redeemContract.foundationEthFeeBps(), 0);
        assertEq(redeemContract.foundationEqtyFeeBps(), 0);
        assertEq(redeemContract.redeemAmount(), REDEEM_AMOUNT);
    }
    
    function test_constructor_revertsOnZeroToken() public {
        vm.expectRevert(RedeemEQTY.InvalidAddress.selector);
        new RedeemEQTY(address(0), foundation);
    }
    
    function test_constructor_revertsOnZeroFoundation() public {
        vm.expectRevert(RedeemEQTY.InvalidAddress.selector);
        new RedeemEQTY(address(eqtyToken), address(0));
    }
    
    // ============ Receive Tests ============
    
    function test_receive_acceptsETH() public {
        uint256 balanceBefore = address(redeemContract).balance;
        vm.prank(alice);
        (bool success, ) = address(redeemContract).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(redeemContract).balance, balanceBefore + 1 ether);
    }
    
    // ============ Redeem Tests (No Fees) ============
    
    function test_redeem_noFees() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        
        uint256 ethBefore = alice.balance;
        uint256 eqtyBefore = eqtyToken.balanceOf(alice);
        uint256 contractEth = address(redeemContract).balance;
        
        redeemContract.redeem();
        
        assertEq(alice.balance, ethBefore + contractEth);
        assertEq(eqtyToken.balanceOf(alice), eqtyBefore - REDEEM_AMOUNT);
        assertEq(redeemContract.pendingFoundationEth(), 0);
        assertEq(redeemContract.pendingFoundationEqty(), 0);
        
        vm.stopPrank();
    }
    
    // ============ Redeem Tests (With ETH Fee) ============
    
    function test_redeem_withEthFee() public {
        redeemContract.setFoundationEthFee(500); // 5%
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        
        uint256 ethBefore = alice.balance;
        uint256 contractEth = address(redeemContract).balance;
        uint256 expectedFee = (contractEth * 500) / 10_000;
        uint256 expectedPayout = contractEth - expectedFee;
        
        redeemContract.redeem();
        
        assertEq(alice.balance, ethBefore + expectedPayout);
        assertEq(redeemContract.pendingFoundationEth(), expectedFee);
        assertEq(redeemContract.pendingFoundationEqty(), 0);
        
        vm.stopPrank();
    }
    
    // ============ Redeem Tests (With EQTY Fee) ============
    
    function test_redeem_withEqtyFee() public {
        redeemContract.setFoundationEqtyFee(1000); // 10%
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        
        uint256 eqtyBefore = eqtyToken.balanceOf(alice);
        uint256 expectedEqtyFee = (uint256(REDEEM_AMOUNT) * 1000) / 10_000;
        
        redeemContract.redeem();
        
        assertEq(eqtyToken.balanceOf(alice), eqtyBefore - REDEEM_AMOUNT);
        assertEq(redeemContract.pendingFoundationEqty(), expectedEqtyFee);
        assertEq(eqtyToken.balanceOf(address(redeemContract)), expectedEqtyFee);
        
        vm.stopPrank();
    }
    
    // ============ Redeem Tests (With Both Fees) ============
    
    function test_redeem_withBothFees() public {
        redeemContract.setFoundationEthFee(500);
        redeemContract.setFoundationEqtyFee(1000);
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        
        uint256 ethBefore = alice.balance;
        uint256 contractEth = address(redeemContract).balance;
        
        uint256 expectedEthFee = (contractEth * 500) / 10_000;
        uint256 expectedEqtyFee = (uint256(REDEEM_AMOUNT) * 1000) / 10_000;
        
        redeemContract.redeem();
        
        assertEq(alice.balance, ethBefore + contractEth - expectedEthFee);
        assertEq(redeemContract.pendingFoundationEth(), expectedEthFee);
        assertEq(redeemContract.pendingFoundationEqty(), expectedEqtyFee);
        
        vm.stopPrank();
    }
    
    // ============ Redeem Tests (100% Fees) ============
    
    function test_redeem_with100PercentFees() public {
        redeemContract.setFoundationEthFee(10_000);
        redeemContract.setFoundationEqtyFee(10_000);
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        
        uint256 ethBefore = alice.balance;
        uint256 contractEth = address(redeemContract).balance;
        
        redeemContract.redeem();
        
        assertEq(alice.balance, ethBefore);
        assertEq(redeemContract.pendingFoundationEth(), contractEth);
        assertEq(redeemContract.pendingFoundationEqty(), REDEEM_AMOUNT);
        
        vm.stopPrank();
    }
    
    // ============ Redeem Error Tests ============
    
    function test_redeem_revertsWithNoETH() public {
        RedeemEQTY emptyContract = new RedeemEQTY(address(eqtyToken), foundation);
        
        vm.startPrank(alice);
        eqtyToken.approve(address(emptyContract), REDEEM_AMOUNT);
        
        vm.expectRevert(RedeemEQTY.InsufficientETH.selector);
        emptyContract.redeem();
        vm.stopPrank();
    }
    
    function test_redeem_revertsWithoutApproval() public {
        vm.prank(alice);
        vm.expectRevert(RedeemEQTY.InsufficientEQTYAllowance.selector);
        redeemContract.redeem();
    }
    
    function test_redeem_revertsWithInsufficientBalance() public {
        vm.startPrank(bob);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        vm.expectRevert(RedeemEQTY.InsufficientEQTYBalance.selector);
        redeemContract.redeem();
        vm.stopPrank();
    }
    
    // ============ Admin Tests ============
    
    function test_setFoundationEthFee_success() public {
        redeemContract.setFoundationEthFee(1000);
        assertEq(redeemContract.foundationEthFeeBps(), 1000);
    }
    
    function test_setFoundationEthFee_allowsMax() public {
        redeemContract.setFoundationEthFee(10_000);
        assertEq(redeemContract.foundationEthFeeBps(), 10_000);
    }
    
    function test_setFoundationEthFee_revertsIfTooHigh() public {
        vm.expectRevert(RedeemEQTY.FeeTooHigh.selector);
        redeemContract.setFoundationEthFee(10_001);
    }
    
    function test_setFoundationEqtyFee_success() public {
        redeemContract.setFoundationEqtyFee(500);
        assertEq(redeemContract.foundationEqtyFeeBps(), 500);
    }
    
    function test_setFoundationEqtyFee_allowsMax() public {
        redeemContract.setFoundationEqtyFee(10_000);
        assertEq(redeemContract.foundationEqtyFeeBps(), 10_000);
    }
    
    function test_setFoundationEqtyFee_revertsIfTooHigh() public {
        vm.expectRevert(RedeemEQTY.FeeTooHigh.selector);
        redeemContract.setFoundationEqtyFee(10_001);
    }
    
    function test_setFoundationWallet_success() public {
        address newWallet = makeAddr("newFoundation");
        redeemContract.setFoundationWallet(newWallet);
        assertEq(redeemContract.foundationWallet(), newWallet);
    }
    
    function test_setRedeemAmount_success() public {
        redeemContract.setRedeemAmount(1_000 ether);
        assertEq(redeemContract.redeemAmount(), 1_000 ether);
    }
    
    function test_setRedeemAmount_allowsVeryHighAmount() public {
        uint128 hugeAmount = type(uint128).max;
        redeemContract.setRedeemAmount(hugeAmount);
        assertEq(redeemContract.redeemAmount(), hugeAmount);
    }
    
    function test_setRedeemAmount_revertsIfZero() public {
        vm.expectRevert(RedeemEQTY.RedeemAmountTooLow.selector);
        redeemContract.setRedeemAmount(0);
    }
    
    // ============ Withdrawal Tests ============
    
    function test_withdrawFoundationEth_success() public {
        redeemContract.setFoundationEthFee(500);
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        redeemContract.redeem();
        vm.stopPrank();
        
        uint256 fees = redeemContract.pendingFoundationEth();
        uint256 foundationBalanceBefore = foundation.balance;
        
        redeemContract.withdrawFoundationEth();
        
        assertEq(foundation.balance, foundationBalanceBefore + fees);
        assertEq(redeemContract.pendingFoundationEth(), 0);
    }
    
    function test_withdrawFoundationEqty_success() public {
        redeemContract.setFoundationEqtyFee(1000);
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        redeemContract.redeem();
        vm.stopPrank();
        
        uint256 fees = redeemContract.pendingFoundationEqty();
        uint256 foundationEqtyBefore = eqtyToken.balanceOf(foundation);
        
        redeemContract.withdrawFoundationEqty();
        
        assertEq(eqtyToken.balanceOf(foundation), foundationEqtyBefore + fees);
        assertEq(redeemContract.pendingFoundationEqty(), 0);
    }
    
    function test_withdrawFoundationEth_revertsIfNoFees() public {
        vm.expectRevert(RedeemEQTY.NoFeesToWithdraw.selector);
        redeemContract.withdrawFoundationEth();
    }
    
    function test_withdrawFoundationEqty_revertsIfNoFees() public {
        vm.expectRevert(RedeemEQTY.NoFeesToWithdraw.selector);
        redeemContract.withdrawFoundationEqty();
    }
    
    // ============ View Tests ============
    
    function test_availableETH_excludesPendingFees() public {
        redeemContract.setFoundationEthFee(500);
        vm.deal(address(redeemContract), 20 ether);
        
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        redeemContract.redeem();
        vm.stopPrank();
        
        uint256 pendingFees = redeemContract.pendingFoundationEth();
        uint256 totalBalance = address(redeemContract).balance;
        
        assertEq(redeemContract.availableETH(), totalBalance - pendingFees);
    }
}
