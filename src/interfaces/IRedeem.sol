// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IRedeem
 * @notice Interface for the Redeem contract
 * @dev Allows EQTY holders to redeem tokens for ETH while tracking a dynamic exchange rate
 */
interface IRedeem {
    // ============ View Functions ============

    /**
     * @notice Get the exchange rate (ETH per redeemAmount of EQTY)
     * @return Exchange rate in wei
     */
    function exchangeRate() external view returns (uint256);

    /**
     * @notice Get the amount of ETH available for redemption
     * @return Available ETH in wei
     */
    function availableEth() external view returns (uint256);

    /**
     * @notice Calculate expected ETH output for a redeem
     * @return ethOut Maximum redeemable ETH after fees
     * @return ethFee ETH fee to foundation
     */
    function previewRedeem() external view returns (uint256 ethOut, uint256 ethFee);

    /**
     * @notice Get the amount of EQTY required per redemption
     * @return Amount in wei
     */
    function redeemAmount() external view returns (uint128);

    // ============ State-Changing Functions ============

    /**
     * @notice Redeem a fixed EQTY amount for an exact ETH output
     * @param ethOut Exact ETH expected after fees
     */
    function redeem(uint256 ethOut) external;

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
    error InvalidExchangeRate();
    error InvalidRedeemAmount();
}
