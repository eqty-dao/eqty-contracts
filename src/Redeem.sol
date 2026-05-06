// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IEQTY
 * @notice Interface for EQTY token with burn functionality
 */
interface IEQTY is IERC20 {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @title Redeem
 * @notice Allows users to redeem EQTY tokens for ETH collected from Ownables fees
 * @dev Implements a "capped percentage update" mechanism for dynamic exchange rates
 *
 * Key mechanics:
 * - Receive ETH from Ownables/Anchor fee payments
 * - Anyone can send EQTY to receive ETH based on current rate
 * - EQTY is burned (deflationary) with optional foundation fee
 * - Exchange rate updates gradually with capped changes per redeem
 * - Anti-frontrunning protection via minEthOut parameter
 *
 * Rate Update Formula:
 *   r_next = r * clamp(p / r, 1 - m, 1 + m)
 * Where:
 *   r = current rate, p = actual payout, m = max change percentage
 */
contract Redeem is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Maximum foundation fee in basis points (100% = 10000 bps)
    uint16 public constant MAX_FEE_BPS = 10_000;

    /// @notice Precision for rate calculations (1e18)
    uint256 public constant RATE_PRECISION = 1e18;

    // ============ Immutables ============

    /// @notice EQTY token contract
    IEQTY public immutable eqtyToken;

    // ============ Packed Storage (Slot 1) ============

    /// @notice Amount of EQTY required to redeem (max ~340 undecillion with uint128)
    uint128 public redeemAmount;

    /// @notice Foundation fee on ETH in basis points (max 10000)
    uint16 public foundationEthFeeBps;

    /// @notice Foundation fee on EQTY in basis points (max 10000)
    uint16 public foundationEqtyFeeBps;

    /// @notice Maximum rate change per redeem in basis points (e.g., 100 = 1%)
    uint16 public maxRateChangeBps;

    // ============ Storage (Slots 2-7) ============

    /// @notice Address to receive foundation fees
    address public foundationWallet;

    /// @notice Current exchange rate: ETH (in wei) per redeemAmount of EQTY
    /// @dev Stored with RATE_PRECISION for accuracy
    uint256 public currentRate;

    /// @notice Minimum allowed rate (floor safety)
    uint256 public minRate;

    /// @notice Maximum allowed rate (ceiling safety)
    uint256 public maxRate;

    /// @notice Accumulated ETH fees available for withdrawal
    uint256 public pendingFoundationEth;

    /// @notice Accumulated EQTY fees available for withdrawal
    uint256 public pendingFoundationEqty;

    // ============ Events ============

    event Redeemed(
        address indexed redeemer,
        uint256 eqtyBurned,
        uint256 eqtyToFoundation,
        uint256 ethReceived,
        uint256 ethToFoundation,
        uint256 newRate
    );
    event FoundationEthFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event FoundationEqtyFeeUpdated(uint16 oldFeeBps, uint16 newFeeBps);
    event FoundationWalletUpdated(address oldWallet, address newWallet);
    event FoundationEthWithdrawn(address indexed to, uint256 amount);
    event FoundationEqtyWithdrawn(address indexed to, uint256 amount);
    event RedeemAmountUpdated(uint128 oldAmount, uint128 newAmount);
    event ETHReceived(address indexed from, uint256 amount);
    event RateUpdated(uint256 oldRate, uint256 newRate);
    event MaxRateChangeUpdated(uint16 oldBps, uint16 newBps);
    event RateBoundsUpdated(uint256 oldMin, uint256 oldMax, uint256 newMin, uint256 newMax);

    // ============ Errors ============

    error InsufficientETH();
    error SlippageExceeded();
    error InsufficientEQTYAllowance();
    error InsufficientEQTYBalance();
    error FeeTooHigh();
    error RedeemAmountTooLow();
    error InvalidAddress();
    error WithdrawalFailed();
    error NoFeesToWithdraw();
    error InvalidRateBounds();
    error RateNotSet();

    // ============ Constructor ============

    /**
     * @notice Deploy the Redeem contract
     * @param _eqtyToken Address of the EQTY token contract
     * @param _foundationWallet Address to receive foundation fees
     */
    constructor(address _eqtyToken, address _foundationWallet) Ownable(msg.sender) {
        if (_eqtyToken == address(0)) revert InvalidAddress();
        if (_foundationWallet == address(0)) revert InvalidAddress();

        eqtyToken = IEQTY(_eqtyToken);
        foundationWallet = _foundationWallet;
        foundationEthFeeBps = 0;
        foundationEqtyFeeBps = 0;
        redeemAmount = 10_000 ether;
        maxRateChangeBps = 1000; // 10% max change per redeem

        // Rate bounds - DAO can adjust these
        minRate = 0;
        maxRate = type(uint256).max;

        // Initial rate must be set by owner before first redeem
        currentRate = 0;
    }

    // ============ External Functions ============

    /**
     * @notice Receive ETH from Ownables/Anchor payments
     */
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    /**
     * @notice Internal redeem implementation
     * @param minEthOut Minimum ETH expected (anti-frontrunning)
     * @dev Burns EQTY from caller (minus foundation fee) and sends ETH (minus foundation fee)
     *      Updates exchange rate using capped percentage formula
     */
    function _redeem(uint256 minEthOut) internal {
        if (currentRate == 0) revert RateNotSet();

        uint256 ethBalance = address(this).balance - pendingFoundationEth;
        if (ethBalance == 0) revert InsufficientETH();

        // Cache storage reads
        uint256 amount = redeemAmount;
        uint256 ethFeeBps = foundationEthFeeBps;
        uint256 eqtyFeeBps = foundationEqtyFeeBps;
        uint256 rate = currentRate;

        // Check allowance and balance
        if (eqtyToken.allowance(msg.sender, address(this)) < amount) {
            revert InsufficientEQTYAllowance();
        }
        if (eqtyToken.balanceOf(msg.sender) < amount) {
            revert InsufficientEQTYBalance();
        }

        // Calculate ETH payout based on current rate
        // rate is ETH per redeemAmount, so ethPayout = rate
        // But cap at available balance
        uint256 ethPayout = rate;
        if (ethPayout > ethBalance) {
            ethPayout = ethBalance;
        }

        // Calculate fees using unchecked for gas savings (overflow impossible with uint16 fees)
        uint256 ethFee;
        uint256 ethToSend;
        uint256 eqtyFee;
        uint256 eqtyToBurn;

        unchecked {
            ethFee = (ethPayout * ethFeeBps) / 10_000;
            ethToSend = ethPayout - ethFee;
            eqtyFee = (amount * eqtyFeeBps) / 10_000;
            eqtyToBurn = amount - eqtyFee;
        }

        // Anti-frontrunning check
        if (ethToSend < minEthOut) revert SlippageExceeded();

        // Update exchange rate using capped percentage formula
        // r_next = r * clamp(p / r, 1 - m, 1 + m)
        uint256 newRate = _calculateNewRate(rate, ethPayout);
        currentRate = newRate;

        // Accumulate foundation fees
        pendingFoundationEth += ethFee;
        pendingFoundationEqty += eqtyFee;

        // Transfer EQTY from user
        if (eqtyFee > 0) {
            IERC20(address(eqtyToken)).safeTransferFrom(msg.sender, address(this), eqtyFee);
        }
        eqtyToken.burnFrom(msg.sender, eqtyToBurn);

        // Send ETH to redeemer
        (bool success,) = msg.sender.call{value: ethToSend}("");
        if (!success) revert WithdrawalFailed();

        emit Redeemed(msg.sender, eqtyToBurn, eqtyFee, ethToSend, ethFee, newRate);
        if (newRate != rate) {
            emit RateUpdated(rate, newRate);
        }
    }

    /**
     * @notice Redeem EQTY tokens for ETH with slippage protection
     * @param minEthOut Minimum ETH expected (anti-frontrunning)
     * @dev Burns EQTY from caller (minus foundation fee) and sends ETH (minus foundation fee)
     *      Updates exchange rate using capped percentage formula
     */
    function redeem(uint256 minEthOut) external nonReentrant {
        _redeem(minEthOut);
    }

    /**
     * @notice Get the amount of ETH available for redemption
     */
    function availableEth() external view returns (uint256) {
        return address(this).balance - pendingFoundationEth;
    }

    /**
     * @notice Calculate expected ETH output for a redeem
     * @return ethOut Expected ETH after fees
     * @return ethFee ETH fee to foundation
     */
    function previewRedeem() external view returns (uint256 ethOut, uint256 ethFee) {
        uint256 ethBalance = address(this).balance - pendingFoundationEth;
        uint256 rate = currentRate;

        uint256 ethPayout = rate;
        if (ethPayout > ethBalance) {
            ethPayout = ethBalance;
        }

        ethFee = (ethPayout * foundationEthFeeBps) / 10_000;
        ethOut = ethPayout - ethFee;
    }

    // ============ Internal Functions ============

    /**
     * @notice Calculate new rate using capped percentage update
     * @param oldRate Current rate
     * @param actualPayout Actual ETH paid out
     * @return newRate Updated rate (clamped within bounds)
     */
    function _calculateNewRate(uint256 oldRate, uint256 actualPayout) internal view returns (uint256 newRate) {
        if (oldRate == 0) return actualPayout;

        // Calculate ratio: actualPayout / oldRate
        // Using RATE_PRECISION for accuracy
        uint256 ratio = (actualPayout * RATE_PRECISION) / oldRate;

        // Calculate bounds: 1 ± maxRateChangeBps
        uint256 lowerBound = RATE_PRECISION - (RATE_PRECISION * maxRateChangeBps / 10_000);
        uint256 upperBound = RATE_PRECISION + (RATE_PRECISION * maxRateChangeBps / 10_000);

        // Clamp ratio to bounds
        if (ratio < lowerBound) {
            ratio = lowerBound;
        } else if (ratio > upperBound) {
            ratio = upperBound;
        }

        // newRate = oldRate * clampedRatio
        newRate = (oldRate * ratio) / RATE_PRECISION;

        // Apply floor and ceiling bounds
        if (newRate < minRate) {
            newRate = minRate;
        } else if (newRate > maxRate) {
            newRate = maxRate;
        }
    }

    // ============ Admin Functions ============

    /**
     * @notice Set the initial exchange rate
     * @param _rate Rate in wei (ETH per redeemAmount of EQTY)
     * @dev Can be called anytime by owner to adjust rate
     */
    function setCurrentRate(uint256 _rate) external onlyOwner {
        uint256 oldRate = currentRate;
        currentRate = _rate;
        emit RateUpdated(oldRate, _rate);
    }

    /**
     * @notice Update the maximum rate change per redeem
     * @param _newBps New max change in basis points (e.g., 100 = 1%)
     */
    function setMaxRateChange(uint16 _newBps) external onlyOwner {
        if (_newBps > MAX_FEE_BPS) revert FeeTooHigh();

        uint16 oldBps = maxRateChangeBps;
        maxRateChangeBps = _newBps;

        emit MaxRateChangeUpdated(oldBps, _newBps);
    }

    /**
     * @notice Update the rate floor and ceiling bounds
     * @param _minRate Minimum allowed rate (can be 0)
     * @param _maxRate Maximum allowed rate
     */
    function setRateBounds(uint256 _minRate, uint256 _maxRate) external onlyOwner {
        if (_minRate > _maxRate) revert InvalidRateBounds();

        uint256 oldMin = minRate;
        uint256 oldMax = maxRate;
        minRate = _minRate;
        maxRate = _maxRate;

        emit RateBoundsUpdated(oldMin, oldMax, _minRate, _maxRate);
    }

    /**
     * @notice Update the foundation ETH fee percentage
     * @param _newFeeBps New fee in basis points (max 10000 = 100%)
     */
    function setFoundationEthFee(uint16 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        uint16 oldFee = foundationEthFeeBps;
        foundationEthFeeBps = _newFeeBps;

        emit FoundationEthFeeUpdated(oldFee, _newFeeBps);
    }

    /**
     * @notice Update the foundation EQTY fee percentage
     * @param _newFeeBps New fee in basis points (max 10000 = 100%)
     */
    function setFoundationEqtyFee(uint16 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        uint16 oldFee = foundationEqtyFeeBps;
        foundationEqtyFeeBps = _newFeeBps;

        emit FoundationEqtyFeeUpdated(oldFee, _newFeeBps);
    }

    /**
     * @notice Update the redeem amount
     * @param _newAmount New amount of EQTY required (minimum 1 wei)
     */
    function setRedeemAmount(uint128 _newAmount) external onlyOwner {
        if (_newAmount == 0) revert RedeemAmountTooLow();

        uint128 oldAmount = redeemAmount;
        redeemAmount = _newAmount;

        emit RedeemAmountUpdated(oldAmount, _newAmount);
    }

    /**
     * @notice Update the foundation wallet address
     */
    function setFoundationWallet(address _newWallet) external onlyOwner {
        if (_newWallet == address(0)) revert InvalidAddress();

        address oldWallet = foundationWallet;
        foundationWallet = _newWallet;

        emit FoundationWalletUpdated(oldWallet, _newWallet);
    }

    /**
     * @notice Withdraw accumulated foundation ETH fees
     */
    function withdrawFoundationEth() external {
        uint256 amount = pendingFoundationEth;
        if (amount == 0) revert NoFeesToWithdraw();

        pendingFoundationEth = 0;

        (bool success,) = foundationWallet.call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit FoundationEthWithdrawn(foundationWallet, amount);
    }

    /**
     * @notice Withdraw accumulated foundation EQTY fees
     */
    function withdrawFoundationEqty() external {
        uint256 amount = pendingFoundationEqty;
        if (amount == 0) revert NoFeesToWithdraw();

        pendingFoundationEqty = 0;

        IERC20(address(eqtyToken)).safeTransfer(foundationWallet, amount);

        emit FoundationEqtyWithdrawn(foundationWallet, amount);
    }
}
