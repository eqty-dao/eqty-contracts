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
     * @notice Get the current exchange rate (ETH per redeemAmount of EQTY)
     * @return Rate in wei
     */
    function currentRate() external view returns (uint256);

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
     * @return Amount in wei (default: 10,000 EQTY)
     */
    function redeemAmount() external view returns (uint128);

    /**
     * @notice Get the maximum rate change allowed per redeem (in basis points)
     * @return Basis points (e.g., 1000 = 10%)
     */
    function maxRateChangeBps() external view returns (uint16);

    /**
     * @notice Get the minimum allowed rate (floor)
     */
    function minRate() external view returns (uint256);

    /**
     * @notice Get the maximum allowed rate (ceiling)
     */
    function maxRate() external view returns (uint256);

    // ============ State-Changing Functions ============

    /**
     * @notice Redeem a fixed EQTY amount for an exact ETH output
     * @param ethOut Exact ETH expected after fees
     */
    function redeem(uint256 ethOut) external;

    // ============ Events ============

    /**
     * @notice Emitted when tokens are redeemed
     * @param redeemer Address that redeemed
     * @param eqtyBurned Amount of EQTY burned
     * @param eqtyToFoundation Amount of EQTY sent to foundation
     * @param ethReceived ETH sent to redeemer
     * @param ethToFoundation ETH sent to foundation
     * @param newRate Updated exchange rate
     */
    event Redeemed(
        address indexed redeemer,
        uint256 eqtyBurned,
        uint256 eqtyToFoundation,
        uint256 ethReceived,
        uint256 ethToFoundation,
        uint256 newRate
    );

    /**
     * @notice Emitted when ETH is received
     * @param from Sender address
     * @param amount Amount received
     */
    event ETHReceived(address indexed from, uint256 amount);

    /**
     * @notice Emitted when the exchange rate is updated
     * @param oldRate Previous rate
     * @param newRate New rate
     */
    event RateUpdated(uint256 oldRate, uint256 newRate);

    // ============ Errors ============

    error InsufficientETH();
    error InsufficientEQTYAllowance();
    error InsufficientEQTYBalance();
}
