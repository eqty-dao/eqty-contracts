// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
 * - Anyone can send EQTY to receive an exact ETH output when enough ETH is available
 * - EQTY is burned (deflationary)
 * - Exchange rate updates gradually with capped changes per redeem
 * - Exact ETH-out redemption for a fixed EQTY input amount
 *
 * Exchange Rate Update Formula:
 *   r_next = r * clamp(p / r, 1 - m, 1 + m)
 * Where:
 *   r = current exchange rate, p = actual payout, m = max change percentage
 */
contract Redeem is ReentrancyGuard {

    // ============ Constants ============

    /// @notice Precision for rate calculations (1e18)
    uint256 public constant RATE_PRECISION = 1e18;

    /// @notice Maximum rate change per redeem in basis points (10%)
    uint16 public constant MAX_RATE_CHANGE_BPS = 1000;

    // ============ Immutables ============

    /// @notice EQTY token contract
    IEQTY public immutable eqtyToken;

    /// @notice Foundation wallet configured at deployment
    address public immutable foundationWallet;

    /// @notice Fixed amount of EQTY burned per redeem
    uint128 public immutable redeemAmount;

    /// @notice Premium applied when Anchor quotes ETH for EQTY-denominated fees
    uint16 public immutable anchorEthPremiumBps;

    // ============ Storage ============

    /// @notice Exchange rate: ETH (in wei) per redeemAmount of EQTY
    /// @dev Stored with RATE_PRECISION for accuracy
    uint256 public exchangeRate;

    // ============ Events ============

    event Redeemed(
        address indexed redeemer,
        uint256 eqtyBurned,
        uint256 eqtyToFoundation,
        uint256 ethReceived,
        uint256 ethToFoundation,
        uint256 newRate
    );
    event ETHReceived(address indexed from, uint256 amount);
    event ExchangeRateUpdated(uint256 oldExchangeRate, uint256 newExchangeRate);
    // ============ Errors ============

    error InsufficientETH();
    error InsufficientEQTYAllowance();
    error InsufficientEQTYBalance();
    error InvalidAddress();
    error InvalidExchangeRate();
    error InvalidRedeemAmount();
    error InvalidAnchorEthPremium();
    error WithdrawalFailed();
    // ============ Constructor ============

    /**
     * @notice Deploy the Redeem contract
     * @param _eqtyToken Address of the EQTY token contract
     * @param _foundationWallet Foundation wallet associated with this deployment
     * @param _initialExchangeRate Initial exchange rate in wei per redeem amount
     * @param _redeemAmount Fixed EQTY amount burned on each redeem
     * @param _anchorEthPremiumBps Premium charged on ETH anchor payments, in basis points
     */
    constructor(
        address _eqtyToken,
        address _foundationWallet,
        uint256 _initialExchangeRate,
        uint128 _redeemAmount,
        uint16 _anchorEthPremiumBps
    ) {
        if (_eqtyToken == address(0)) revert InvalidAddress();
        if (_foundationWallet == address(0)) revert InvalidAddress();
        if (_initialExchangeRate == 0) revert InvalidExchangeRate();
        if (_redeemAmount == 0) revert InvalidRedeemAmount();
        if (_anchorEthPremiumBps > 10_000) revert InvalidAnchorEthPremium();

        eqtyToken = IEQTY(_eqtyToken);
        foundationWallet = _foundationWallet;
        exchangeRate = _initialExchangeRate;
        redeemAmount = _redeemAmount;
        anchorEthPremiumBps = _anchorEthPremiumBps;
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
     * @param ethOut Exact ETH expected after fees
     * @dev Burns EQTY from caller and sends exact ETH out
     *      Updates exchange rate using capped percentage formula
     */
    function _redeem(uint256 ethOut) internal {
        uint256 ethBalance = address(this).balance;

        // Cache storage reads
        uint256 amount = redeemAmount;

        // Check allowance and balance
        if (eqtyToken.allowance(msg.sender, address(this)) < amount) {
            revert InsufficientEQTYAllowance();
        }
        if (eqtyToken.balanceOf(msg.sender) < amount) {
            revert InsufficientEQTYBalance();
        }

        uint256 ethPayout = ethOut;
        if (ethPayout > ethBalance) revert InsufficientETH();

        uint256 eqtyToBurn = amount;
        uint256 newExchangeRate = _updateExchangeRate(ethPayout);

        eqtyToken.burnFrom(msg.sender, eqtyToBurn);

        // Send ETH to redeemer
        (bool success,) = msg.sender.call{value: ethOut}("");
        if (!success) revert WithdrawalFailed();

        emit Redeemed(msg.sender, eqtyToBurn, 0, ethOut, 0, newExchangeRate);
    }

    /**
     * @notice Redeem a fixed EQTY amount for an exact ETH output
     * @param ethOut Exact ETH expected after fees
     * @dev Burns EQTY from caller and sends exact ETH out
     *      Updates exchange rate using capped percentage formula
     */
    function redeem(uint256 ethOut) external nonReentrant {
        _redeem(ethOut);
    }

    /**
     * @notice Get the amount of ETH available for redemption
     */
    function availableEth() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Calculate expected ETH output for a redeem
     * @return ethOut Maximum redeemable ETH after fees
     * @return ethFee ETH fee to foundation
     */
    function previewRedeem() external view returns (uint256 ethOut, uint256 ethFee) {
        return (address(this).balance, 0);
    }

    /**
     * @notice Quote the ETH required to pay an anchor fee denominated in EQTY
     * @param eqtyAmount EQTY amount being priced
     * @return ETH required in wei, including the configured premium
     */
    function quoteAnchorFee(uint256 eqtyAmount) external view returns (uint256) {
        uint256 baseEthAmount = (exchangeRate * eqtyAmount) / redeemAmount;
        uint256 premium = (baseEthAmount * anchorEthPremiumBps) / 10_000;
        return baseEthAmount + premium;
    }

    // ============ Internal Functions ============

    /**
     * @notice Update the exchange rate after a redeem
     * @param actualPayout Gross ETH paid out for the redeem including foundation fee
     * @return newExchangeRate Updated exchange rate
     */
    function _updateExchangeRate(uint256 actualPayout) private returns (uint256 newExchangeRate) {
        uint256 oldExchangeRate = exchangeRate;
        newExchangeRate = _calculateNewExchangeRate(oldExchangeRate, actualPayout);
        exchangeRate = newExchangeRate;

        if (newExchangeRate != oldExchangeRate) {
            emit ExchangeRateUpdated(oldExchangeRate, newExchangeRate);
        }
    }

    /**
     * @notice Calculate new exchange rate using capped percentage update
     * @param oldExchangeRate Current exchange rate
     * @param actualPayout Actual ETH paid out
     * @return newExchangeRate Updated exchange rate
     */
    function _calculateNewExchangeRate(uint256 oldExchangeRate, uint256 actualPayout) internal pure returns (uint256 newExchangeRate) {
        if (oldExchangeRate == 0) return actualPayout;

        // Calculate ratio: actualPayout / oldExchangeRate
        // Using RATE_PRECISION for accuracy
        uint256 ratio = (actualPayout * RATE_PRECISION) / oldExchangeRate;

        // Calculate bounds: 1 ± 10%
        uint256 lowerBound = RATE_PRECISION - (RATE_PRECISION * MAX_RATE_CHANGE_BPS / 10_000);
        uint256 upperBound = RATE_PRECISION + (RATE_PRECISION * MAX_RATE_CHANGE_BPS / 10_000);

        // Clamp ratio to bounds
        if (ratio < lowerBound) {
            ratio = lowerBound;
        } else if (ratio > upperBound) {
            ratio = upperBound;
        }

        // newExchangeRate = oldExchangeRate * clampedRatio
        newExchangeRate = (oldExchangeRate * ratio) / RATE_PRECISION;

    }
}
