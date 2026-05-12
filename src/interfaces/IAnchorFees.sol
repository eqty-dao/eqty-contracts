// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAnchorFees
 * @notice Interface for reading anchor fee quotes
 */
interface IAnchorFees {
    /**
     * @notice Quote the total EQTY cost for a number of billable items
     * @param count Number of billable items
     * @return Total EQTY required in wei
     */
    function quoteEqtyCost(uint256 count) external view returns (uint256);

    /**
     * @notice Quote the total ETH cost for a number of billable items
     * @param count Number of billable items
     * @return Total ETH required in wei
     */
    function quoteEthCost(uint256 count) external view returns (uint256);
}
