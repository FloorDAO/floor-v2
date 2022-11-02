// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * The Uniswap pricing executor will query either a singular token or multiple
 * tokens in a peripheral multicall to return a price of TOKEN -> ETH. We will
 * need to calculate the pool address for TOKEN:ETH and then find the spot
 * price.
 *
 * Multicall documentation can be found here:
 * https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol
 *
 * We will also find the spot price of the FLOOR:ETH pool so that we can calculate
 * TOKEN -> FLOOR via ETH as an interim.
 */
interface IUniswapV3PricingExecutor {

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
     *
     * To update the price, we will want to `observe` the `UniswapV3Pool`:
     * https://docs.uniswap.org/protocol/reference/core/UniswapV3Pool#observe
     */
    function updatePrice(address token) external returns (uint);

    /**
     * Updates our price of an array of tokens in ETH value.
     *
     * To update the price, we will want to `observe` the `UniswapV3Pool`:
     * https://docs.uniswap.org/protocol/reference/core/UniswapV3Pool#observe
     */
    function updatePrice(address[] memory token) external returns (uint[] memory);

}
