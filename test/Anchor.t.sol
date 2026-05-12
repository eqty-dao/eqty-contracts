// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Anchor} from "../src/Anchor.sol";
import {IAnchor} from "../src/interfaces/IAnchor.sol";
import {IPublicEvent} from "../src/interfaces/IPublicEvent.sol";
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
        anchorContract.setEqtyFee(ANCHOR_FEE);

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
        assertEq(freshAnchor.eqtyFee(), 0);
        assertEq(address(freshAnchor.eqtyToken()), address(0));
    }

    // ============ Fee Mechanism Tests ============

    function test_anchor_burnsEQTYAsFee() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);

        uint256 balanceBefore = eqtyToken.balanceOf(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

        anchorContract.anchor(anchors);

        assertEq(eqtyToken.balanceOf(alice), balanceBefore - ANCHOR_FEE);
        vm.stopPrank();
    }

    function test_setEqtyFee_onlyOwner() public {
        uint256 newFee = 0.5 ether;
        anchorContract.setEqtyFee(newFee);
        assertEq(anchorContract.eqtyFee(), newFee);
    }

    function test_setEqtyFee_revertsForNonOwner_duplicate() public {
        vm.prank(alice);
        vm.expectRevert();
        anchorContract.setEqtyFee(0.5 ether);
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
        anchorContract.setEqtyFee(0);

        vm.startPrank(alice);
        uint256 balanceBefore = eqtyToken.balanceOf(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

        anchorContract.anchor(anchors);

        assertEq(eqtyToken.balanceOf(alice), balanceBefore); // No tokens burned
        vm.stopPrank();
    }

    function test_anchor_noFeeWhenNoToken() public {
        anchorContract.setEqtyToken(address(0));

        vm.startPrank(alice);
        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

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

    // ============ Public Event Tests ============

    function test_emitPublicEvent_emitsCanonicalEvent() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);

        bytes32 subjectId = keccak256("subject-123");
        string memory eventType = "consume";
        bytes memory data = abi.encode(uint256(1), alice);

        vm.expectEmit(true, true, false, true);
        emit IPublicEvent.PublicEvent(subjectId, alice, eventType, data, uint64(block.timestamp));

        anchorContract.emitPublicEvent(subjectId, eventType, data);
        vm.stopPrank();
    }

    function test_emitPublicEvent_burnsEQTYAsFee() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE);

        uint256 balanceBefore = eqtyToken.balanceOf(alice);

        anchorContract.emitPublicEvent(keccak256("subject-123"), "consume", hex"deadbeef");

        assertEq(eqtyToken.balanceOf(alice), balanceBefore - ANCHOR_FEE);
        vm.stopPrank();
    }

    function test_emitPublicEvent_noFeeWhenZeroFee() public {
        anchorContract.setEqtyFee(0);

        vm.startPrank(alice);
        uint256 balanceBefore = eqtyToken.balanceOf(alice);

        anchorContract.emitPublicEvent(keccak256("subject-123"), "consume", hex"00");

        assertEq(eqtyToken.balanceOf(alice), balanceBefore);
        vm.stopPrank();
    }

    // ============ Batch Anchor Tests ============

    function test_anchor_batch10() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), ANCHOR_FEE * 10);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](10);
        for (uint256 i = 0; i < 10; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)), value: keccak256(abi.encodePacked("value-", i))
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
                key: keccak256(abi.encodePacked("key-", i)), value: keccak256(abi.encodePacked("value-", i))
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
                key: keccak256(abi.encodePacked("key-", i)), value: keccak256(abi.encodePacked("value-", i))
            });
        }

        vm.expectRevert(Anchor.TooManyAnchors.selector);
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
                key: keccak256(abi.encodePacked("key-", i)), value: keccak256(abi.encodePacked("value-", i))
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
                key: keccak256(abi.encodePacked("key-", i)), value: keccak256(abi.encodePacked("value-", i))
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

    // ============ ETH Payment Tests ============

    function test_setRedeemContract_onlyOwner() public {
        address redeem = makeAddr("redeem");
        anchorContract.setRedeemContract(redeem);
        assertEq(address(anchorContract.redeemContract()), redeem);
    }

    function test_setRedeemContract_revertsForNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        anchorContract.setRedeemContract(makeAddr("redeem"));
    }

    function test_getEthFee_returnsZeroWithoutRedeemContract() public view {
        assertEq(anchorContract.getEthFee(), 0);
    }

    function test_anchor_withETH_revertsWithoutRedeemContract() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

        vm.expectRevert(Anchor.RedeemContractNotSet.selector);
        anchorContract.anchor{value: 1 ether}(anchors);

        vm.stopPrank();
    }

    function test_previewEthCost_returnsZeroWithoutRedeemContract() public view {
        assertEq(anchorContract.previewEthCost(5), 0);
    }
}

// ============ ETH Payment Integration Tests ============

/**
 * @title MockRedeem
 * @notice Mock Redeem contract for testing ETH payments
 */
contract MockRedeem {
    uint256 public exchangeRate;
    uint256 public receivedETH;
    uint128 public redeemAmount;
    uint16 public anchorEthPremiumBps;

    constructor(uint256 _rate, uint128 _redeemAmount, uint16 _anchorEthPremiumBps) {
        exchangeRate = _rate;
        redeemAmount = _redeemAmount;
        anchorEthPremiumBps = _anchorEthPremiumBps;
    }

    receive() external payable {
        receivedETH += msg.value;
    }

    function quoteAnchorFee(uint256 eqtyAmount) external view returns (uint256) {
        uint256 baseEthAmount = (exchangeRate * eqtyAmount) / redeemAmount;
        uint256 premium = (baseEthAmount * anchorEthPremiumBps) / 10_000;
        return baseEthAmount + premium;
    }
}

contract AnchorETHPaymentTest is Test {
    Anchor public anchorContract;
    MockEQTY public eqtyToken;
    MockRedeem public redeemContract;

    address public alice = makeAddr("alice");

    uint256 public constant EXCHANGE_RATE = 0.1 ether;
    uint128 public constant REDEEM_AMOUNT = 10_000 ether;
    uint16 public constant ANCHOR_ETH_PREMIUM_BPS = 2000;
    uint256 public constant EQTY_FEE = 100 ether;
    uint256 public constant ETH_FEE = 0.0012 ether;

    function setUp() public {
        eqtyToken = new MockEQTY();
        anchorContract = new Anchor();
        redeemContract = new MockRedeem(EXCHANGE_RATE, REDEEM_AMOUNT, ANCHOR_ETH_PREMIUM_BPS);

        // Configure anchor contract
        anchorContract.setEqtyToken(address(eqtyToken));
        anchorContract.setEqtyFee(EQTY_FEE);
        anchorContract.setRedeemContract(address(redeemContract));

        // Give alice EQTY and ETH
        eqtyToken.mint(alice, 1000 ether);
        vm.deal(alice, 10 ether);
    }

    function test_anchor_withETH_forwardsToRedeem() public {
        vm.startPrank(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

        uint256 redeemBalanceBefore = address(redeemContract).balance;

        anchorContract.anchor{value: ETH_FEE}(anchors);

        assertEq(address(redeemContract).balance, redeemBalanceBefore + ETH_FEE);
        assertEq(redeemContract.receivedETH(), ETH_FEE);

        vm.stopPrank();
    }

    function test_anchor_withETH_multiplAnchors() public {
        vm.startPrank(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](5);
        for (uint256 i = 0; i < 5; i++) {
            anchors[i] = IAnchor.Anchor({
                key: keccak256(abi.encodePacked("key-", i)), value: keccak256(abi.encodePacked("value-", i))
            });
        }

        uint256 requiredEth = ETH_FEE * 5;

        anchorContract.anchor{value: requiredEth}(anchors);

        assertEq(redeemContract.receivedETH(), requiredEth);

        vm.stopPrank();
    }

    function test_anchor_withETH_revertsOnInsufficientPayment() public {
        vm.startPrank(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](2);
        anchors[0] = IAnchor.Anchor({key: keccak256("key1"), value: keccak256("value1")});
        anchors[1] = IAnchor.Anchor({key: keccak256("key2"), value: keccak256("value2")});

        // Only pay for 1 anchor when submitting 2
        vm.expectRevert(Anchor.InsufficientETH.selector);
        anchorContract.anchor{value: ETH_FEE}(anchors);

        vm.stopPrank();
    }

    function test_anchor_withETH_doesNotBurnEQTY() public {
        vm.startPrank(alice);

        // Approve EQTY just in case
        eqtyToken.approve(address(anchorContract), EQTY_FEE);

        uint256 eqtyBalanceBefore = eqtyToken.balanceOf(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

        anchorContract.anchor{value: ETH_FEE}(anchors);

        // EQTY should not have been burned
        assertEq(eqtyToken.balanceOf(alice), eqtyBalanceBefore);

        vm.stopPrank();
    }

    function test_getEthFee_returnsRateFromRedeem() public view {
        assertEq(anchorContract.getEthFee(), ETH_FEE);
    }

    function test_previewEthCost_calculatesCorrectly() public view {
        assertEq(anchorContract.previewEthCost(1), ETH_FEE);
        assertEq(anchorContract.previewEthCost(5), ETH_FEE * 5);
        assertEq(anchorContract.previewEthCost(100), ETH_FEE * 100);
    }

    function test_anchor_withEQTY_stillWorks() public {
        vm.startPrank(alice);
        eqtyToken.approve(address(anchorContract), EQTY_FEE);

        uint256 balanceBefore = eqtyToken.balanceOf(alice);

        IAnchor.Anchor[] memory anchors = new IAnchor.Anchor[](1);
        anchors[0] = IAnchor.Anchor({key: keccak256("test-key"), value: keccak256("test-value")});

        // No ETH sent - should use EQTY
        anchorContract.anchor(anchors);

        assertEq(eqtyToken.balanceOf(alice), balanceBefore - EQTY_FEE);

        vm.stopPrank();
    }

    function test_emitPublicEvent_withETH_forwardsToRedeem() public {
        vm.startPrank(alice);

        uint256 redeemBalanceBefore = address(redeemContract).balance;
        bytes memory data = abi.encode(uint256(1), alice);

        anchorContract.emitPublicEvent{value: ETH_FEE}(keccak256("subject-123"), "consume", data);

        assertEq(address(redeemContract).balance, redeemBalanceBefore + ETH_FEE);
        assertEq(redeemContract.receivedETH(), ETH_FEE);

        vm.stopPrank();
    }
}
