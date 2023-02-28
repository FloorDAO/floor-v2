// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import '../../src/interfaces/pricing/BasePricingExecutor.sol';

/**
 * The mock pricing executor will return prices for a set list of token addresses.
 */
contract PricingExecutorMock is IBasePricingExecutor {
    // Ensures floor is cast to address * 11 and the ETH price will just be a
    // direct 1:1 relation of the address uint value.
    uint160 floor = 11;

    /**
     * Name of the pricing executor.
     */
    function name() external pure returns (string memory) {
        return 'PricingExecutorMock';
    }

    /**
     * Gets our live price of a token to ETH.
     */
    function getETHPrice(address token) external pure returns (uint) {
        return _getPrice(token);
    }

    /**
     * Gets our live prices of multiple tokens to ETH.
     */
    function getETHPrices(address[] memory tokens) external pure returns (uint[] memory output) {
        return _getPrices(tokens);
    }

    /**
     * Gets a live mapped price of a token to FLOOR, returned in the correct decimal
     * count for the target token.
     *
     * We get the latest price of not only the requested token, but also for the
     * FLOOR token. We can then determine the amount of returned token based on
     * live price values.
     */
    function getFloorPrice(address token) external view returns (uint) {
        address[] memory tokens = new address[](2);
        tokens[0] = token;
        tokens[1] = address(floor);

        uint[] memory prices = _getPrices(tokens);
        return _calculateFloorPrice(token, prices[0], prices[1]);
    }

    /**
     * Gets a live mapped price of multiple tokens to FLOOR.
     */
    function getFloorPrices(address[] memory tokens) external view returns (uint[] memory) {
        // We first need to get our Floor price, as well as our token prices
        uint floorPrice = _getPrice(address(floor));
        uint[] memory prices = _getPrices(tokens);

        // Gas saves by storing the array length
        uint tokensLength = tokens.length;

        // We only need to store the same number of tokens passed in, so we exclude
        // our additional floor price request from the response.
        uint[] memory output = new uint[](tokensLength);

        // Each iteration requires us to calculate the floor price based on the token
        // so that we can return the token amount in the correct decimal accuracy.
        for (uint i; i < tokensLength;) {
            output[i] = prices[i] * floorPrice;
            unchecked {
                ++i;
            }
        }

        return output;
    }

    function getLatestFloorPrice(address token) external pure returns (uint) {
        return _getPrice(token);
    }

    function getLiquidity(address token) external pure returns (uint) {
        return 1 ether;
    }

    /**
     * This helper function allows us to return the amount of tokens a user would receive
     * for 1 FLOOR token, returned in the decimal accuracy of the base token.
     */
    function _calculateFloorPrice(address token, uint tokenPrice, uint floorPrice) internal view returns (uint) {
        return (floorPrice * 10 ** ERC20(token).decimals()) / tokenPrice;
    }

    /**
     * Retrieves the token price in WETH from a Uniswap pool.
     */
    function _getPrice(address token) internal pure returns (uint) {
        return uint(uint160(token));
    }

    /**
     * This means that this function essentially acts as an intermediary function that just
     * subsequently calls `_getPrice` for each token passed. Not really gas efficient, but
     * unfortunately the best we can do with what we have.
     */
    function _getPrices(address[] memory tokens) internal pure returns (uint[] memory) {
        uint[] memory prices = new uint[](tokens.length);
        for (uint i; i < tokens.length;) {
            prices[i] = _getPrice(tokens[i]);
            unchecked {
                ++i;
            }
        }
        return prices;
    }
}
