// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Redeem} from "../src/Redeem.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

contract RedeemTest is Test {
    Redeem public redeemContract;
    MockEQTY public eqtyToken;

    address public foundation = makeAddr("foundation");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint128 public constant REDEEM_AMOUNT = 10_000 ether;
    uint256 public constant INITIAL_EXCHANGE_RATE = 1 ether;

    function setUp() public {
        eqtyToken = new MockEQTY();
        redeemContract = new Redeem(address(eqtyToken), foundation, INITIAL_EXCHANGE_RATE, REDEEM_AMOUNT);
        eqtyToken.mint(alice, uint256(REDEEM_AMOUNT) * 10);
        vm.deal(address(redeemContract), 10 ether);
    }

    function test_constructor_setsValues() public view {
        assertEq(address(redeemContract.eqtyToken()), address(eqtyToken));
        assertEq(redeemContract.foundationWallet(), foundation);
        assertEq(redeemContract.redeemAmount(), REDEEM_AMOUNT);
        assertEq(redeemContract.MAX_RATE_CHANGE_BPS(), 1000);
        assertEq(redeemContract.exchangeRate(), INITIAL_EXCHANGE_RATE);
    }

    function test_constructor_revertsOnZeroToken() public {
        vm.expectRevert(Redeem.InvalidAddress.selector);
        new Redeem(address(0), foundation, INITIAL_EXCHANGE_RATE, REDEEM_AMOUNT);
    }

    function test_constructor_revertsOnZeroFoundation() public {
        vm.expectRevert(Redeem.InvalidAddress.selector);
        new Redeem(address(eqtyToken), address(0), INITIAL_EXCHANGE_RATE, REDEEM_AMOUNT);
    }

    function test_constructor_revertsOnZeroExchangeRate() public {
        vm.expectRevert(Redeem.InvalidExchangeRate.selector);
        new Redeem(address(eqtyToken), foundation, 0, REDEEM_AMOUNT);
    }

    function test_constructor_revertsOnZeroRedeemAmount() public {
        vm.expectRevert(Redeem.InvalidRedeemAmount.selector);
        new Redeem(address(eqtyToken), foundation, INITIAL_EXCHANGE_RATE, 0);
    }

    function test_receive_acceptsETH() public {
        uint256 balanceBefore = address(redeemContract).balance;
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        (bool success,) = address(redeemContract).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(redeemContract).balance, balanceBefore + 1 ether);
    }

    function test_redeem_noFees() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);

        uint256 ethBefore = alice.balance;
        uint256 eqtyBefore = eqtyToken.balanceOf(alice);

        redeemContract.redeem(0.1 ether);

        assertEq(alice.balance, ethBefore + 0.1 ether);
        assertEq(eqtyToken.balanceOf(alice), eqtyBefore - REDEEM_AMOUNT);
        assertEq(redeemContract.exchangeRate(), 0.9 ether);
        vm.stopPrank();
    }

    function test_redeem_revertsWhenRequestedAmountExceedsAvailable() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        vm.expectRevert(Redeem.InsufficientETH.selector);
        redeemContract.redeem(11 ether);
        vm.stopPrank();
    }

    function test_redeem_revertsWithoutApproval() public {
        vm.prank(alice);
        vm.expectRevert(Redeem.InsufficientEQTYAllowance.selector);
        redeemContract.redeem(0.1 ether);
    }

    function test_redeem_revertsWithInsufficientBalance() public {
        vm.startPrank(bob);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        vm.expectRevert(Redeem.InsufficientEQTYBalance.selector);
        redeemContract.redeem(0.1 ether);
        vm.stopPrank();
    }

    function test_redeem_usesRequestedAmountWithInitialExchangeRate() public {
        Redeem freshContract = new Redeem(address(eqtyToken), foundation, INITIAL_EXCHANGE_RATE, REDEEM_AMOUNT);
        vm.deal(address(freshContract), 10 ether);

        vm.startPrank(alice);
        eqtyToken.approve(address(freshContract), REDEEM_AMOUNT);
        uint256 ethBefore = alice.balance;
        freshContract.redeem(0.1 ether);
        assertEq(alice.balance, ethBefore + 0.1 ether);
        assertEq(freshContract.exchangeRate(), 0.9 ether);
        vm.stopPrank();
    }

    function test_redeem_rateUpdatesCappedDown() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT * 2);
        uint256 rateBefore = redeemContract.exchangeRate();
        redeemContract.redeem(0.1 ether);
        uint256 rateAfter = redeemContract.exchangeRate();
        assertTrue(rateAfter < rateBefore);
        assertGe(rateAfter, rateBefore - ((rateBefore * 1000) / 10_000));
        vm.stopPrank();
    }

    function test_redeem_rateUpdatesCappedUp() public {
        vm.deal(address(redeemContract), 100 ether);

        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT * 2);
        uint256 rateBefore = redeemContract.exchangeRate();
        redeemContract.redeem(10 ether);
        uint256 rateAfter = redeemContract.exchangeRate();
        assertTrue(rateAfter > rateBefore);
        assertLe(rateAfter, rateBefore + ((rateBefore * 1000) / 10_000));
        vm.stopPrank();
    }

    function test_availableEth_matchesBalance() public {
        assertEq(redeemContract.availableEth(), 10 ether);

        vm.startPrank(alice);
        eqtyToken.approve(address(redeemContract), REDEEM_AMOUNT);
        redeemContract.redeem(0.95 ether);
        vm.stopPrank();

        assertEq(redeemContract.availableEth(), 9.05 ether);
    }

    function test_previewRedeem_returnsBalanceAndZeroFee() public view {
        (uint256 ethOut, uint256 ethFee) = redeemContract.previewRedeem();
        assertEq(ethOut, 10 ether);
        assertEq(ethFee, 0);
    }
}
