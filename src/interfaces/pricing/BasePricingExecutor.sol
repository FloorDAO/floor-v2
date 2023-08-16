// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Pricing Executors will provide our Treasury with the pricing knowledge needed
 * to equate a reward token to ETH. Each executor will implement a single pricing
 * strategy that can be implemented by the Treasury.
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
     * If applicable, gets the amount of liquidity held in a pairing.
     */
    function getLiquidity(address token) external returns (uint);
}
