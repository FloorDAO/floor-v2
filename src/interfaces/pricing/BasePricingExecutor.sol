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
    * Returns `true` if the contract implements the pricing exector `interfaceID`, `false` otherwise.
    * @param interfaceID The interface identifier
    */
    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    /**
     * Gets our current mapped price of a token to ETH.
     */
    function getETHPrice(address token) external view returns (uint);

    /**
     * Gets our current mapped price of multiple tokens to ETH.
     */
    function getETHPrice(address[] memory token) external view returns (uint[] memory);

    /**
     * Gets our current mapped price of a token to FLOOR.
     */
    function getFloorPrice(address token) external view returns (uint);

    /**
     * Gets our current mapped price of multiple tokens to FLOOR.
     */
    function getFloorPrice(address[] memory token) external view returns (uint[] memory);

    /**
     * Gets the timestamp of when the price was last updated by the executor.
     */
    function getPriceFreshness(address token) external view returns (uint);

    /**
     * Updates our price of a token in ETH value.
     */
    function updatePrice(address token) external returns (uint);

    /**
     * Updates our price of an array of tokens in ETH value.
     */
    function updatePrice(address[] memory token) external returns (uint[] memory);

}
