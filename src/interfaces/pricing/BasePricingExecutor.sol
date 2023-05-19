// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Pricing Executors will provide our Treasury with the pricing knowledge needed
 * to equate a reward token to that of FLOOR. Each executor will implement a single
 * pricing strategy that can be implemented by the Treasury.
 *
 * This base strategy will need to be inherited and extended upon by other pricing
 * exectors to ensure that the required logic and functionality is made available.
 */
interface IBasePricingExecutor {
    /// @dev When a token price is updated
    event TokenPriceUpdated(address token, uint amount);

    /**
     * Name of the pricing executor.
     */
    function name() external view returns (string memory);

    /**
     * Gets our current mapped price of a token to ETH.
     */
    function getETHPrice(address token) external returns (uint);

    /**
     * Gets our current mapped price of multiple tokens to ETH.
     */
    function getETHPrices(address[] memory token) external returns (uint[] memory);

    /**
     * Gets our current mapped price of a token to FLOOR.
     */
    function getFloorPrice(address token) external returns (uint);

    /**
     * Gets our current mapped price of multiple tokens to FLOOR.
     */
    function getFloorPrices(address[] memory token) external returns (uint[] memory);

    /**
     * Gets the latest stored FLOOR token price equivalent to a token. If the price has
     * not been queried before, then we cache and return a new price.
     */
    function getLatestFloorPrice(address token) external view returns (uint);

    /**
     * ..
     */
    function getLiquidity(address token) external returns (uint);
}
