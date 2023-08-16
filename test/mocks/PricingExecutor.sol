// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';

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

    function getLiquidity(address /* token */ ) external pure returns (uint) {
        return 1 ether;
    }

    /**
     * Retrieves the token price in WETH from a Uniswap pool.
     */
    function _getPrice(address token) internal pure returns (uint) {
        return uint(uint160(token)) * 1 ether;
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
