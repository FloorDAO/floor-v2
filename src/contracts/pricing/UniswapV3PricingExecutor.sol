// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20Metadata} from '@openzeppelin/contracts/interfaces/IERC20Metadata.sol';

import {FullMath} from '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3Pool, IUniswapV3PoolDerivedState} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/// If we are unable to find a pool for the Uniswap token combination
error UnknownUniswapPool();


/**
 * The Uniswap pricing executor will query either a singular token or multiple
 * tokens in a peripheral multicall to return a price of TOKEN -> ETH. We will
 * need to calculate the pool address for TOKEN:ETH and then find the spot
 * price.
 */
contract UniswapV3PricingExecutor is IBasePricingExecutor {
    /// Maintain an immutable address of the Uniswap V3 Pool Factory contract
    IUniswapV3Factory public immutable uniswapV3PoolFactory;

    /// The WETH contract address used for price mappings
    IWETH public immutable WETH;

    /// Keep a cache of our pool addresses for gas optimisation
    mapping(address => address) private _poolAddresses;

    /**
     * Set our immutable contract addresses.
     *
     * @dev Mainnet UniswapV3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984
     */
    constructor(address _poolFactory, address _weth) {
        if (_poolFactory == address(0) || _weth == address(0)) revert CannotSetNullAddress();

        uniswapV3PoolFactory = IUniswapV3Factory(_poolFactory);
        WETH = IWETH(_weth);
    }

    /**
     * Name of the pricing executor; this should be unique from other pricing executors.
     *
     * @return string Pricing Executor name
     */
    function name() external pure returns (string memory) {
        return 'UniswapV3PricingExecutor';
    }

    /**
     * Gets our live price of a token to ETH.
     *
     * @param token Token to find price of
     *
     * @return uint The ETH value of a singular token
     */
    function getETHPrice(address token) external returns (uint) {
        return _getPrice(token);
    }

    /**
     * Gets our live prices of multiple tokens to ETH.
     *
     * @param tokens[] Tokens to find price of
     *
     * @return uint[] The ETH values of a singular token, mapping to passed token index
     */
    function getETHPrices(address[] calldata tokens) external returns (uint[] memory) {
        return _getPrices(tokens);
    }

    /**
     * Returns the pool address for a given pair of tokens and a fee, or address 0 if
     * it does not exist. The secondary token will always be WETH for our requirements,
     * so this is just passed in from our contract constant.
     *
     * For gas optimisation, we cache the pool address that is calculated, to prevent
     * subsequent external calls being required.
     *
     * @param token The token contract to find the ETH pool of
     *
     * @return address The UniSwap ETH:token pool
     */
    function _poolAddress(address token) internal returns (address) {
        // If we have a cached pool, then reference this for gas saves
        address _tokenPoolAddress = _poolAddresses[token];
        if (_tokenPoolAddress != address(0)) {
            return _tokenPoolAddress;
        }

        // Load our candidate pool at 1% fee
        address candidatePool = uniswapV3PoolFactory.getPool(token, address(WETH), 1_0000);

        // If we can't find a pool, then we need to raise an error
        if (candidatePool == address(0)) {
            revert UnknownUniswapPool();
        }

        // Store the token pool into our internal cache and return the address
        return _poolAddresses[token] = candidatePool;
    }

    /**
     * Retrieves the token price in WETH from a Uniswap pool.
     *
     * @param token The token contract to find the ETH price of
     *
     * @return Price of the token in ETH
     */
    function _getPrice(address token) internal returns (uint) {
        // Ensure our token decimals don't exceed the standard 18
        uint tokenDecimals = IERC20Metadata(token).decimals();
        require(tokenDecimals <= 18, 'Invalid token decimals');

        // We can get the cached / fresh pool address for our token <-> WETH pool. If the
        // pool doesn't exist then this function will revert our tx.
        address pool = _poolAddress(token);

        // Set our default TWAP ago time
        uint ago = 1800;

        // We set our TWAP range to 30 minutes
        uint32[] memory secondsAgos = new uint32[](2);
        (secondsAgos[0], secondsAgos[1]) = (uint32(ago), 0);

        // If we cannot find an observation for our desired time, then we attempt to fallback
        // on the latest observation available to us
        (bool success, bytes memory data) = pool.staticcall(abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector, secondsAgos));
        if (!success) {
            if (keccak256(data) != keccak256(abi.encodeWithSignature('Error(string)', 'OLD'))) revertBytes(data);

            // The oldest available observation in the ring buffer is the index following the current (accounting for wrapping),
            // since this is the one that will be overwritten next.
            (,, uint16 index, uint16 cardinality,,,) = IUniswapV3Pool(pool).slot0();
            (uint32 oldestAvailableAge,,, bool initialized) = IUniswapV3Pool(pool).observations((index + 1) % cardinality);

            // If the following observation in a ring buffer of our current cardinality is uninitialized, then all the
            // observations at higher indices are also uninitialized, so we wrap back to index 0, which we now know
            // to be the oldest available observation.
            if (!initialized) (oldestAvailableAge,,,) = IUniswapV3Pool(pool).observations(0);

            // Update our "ago" seconds to the value of the latest observation
            ago = block.timestamp - oldestAvailableAge;
            secondsAgos[0] = uint32(ago);

            // Call observe() again to get the oldest available
            (success, data) = pool.staticcall(abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector, secondsAgos));
            if (!success) revertBytes(data);
        }

        // If uniswap pool doesn't exist, then data will be empty and this decode will throw:
        int56[] memory tickCumulatives = abi.decode(data, (int56[])); // don't bother decoding the liquidityCumulatives array

        // Get our tick value from the cumulatives
        int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int(ago)));

        // Get our token price
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        return _decodeSqrtPriceX96(token, 10 ** (18 - tokenDecimals), sqrtPriceX96);
    }

    /**
     * Decodes the `SqrtPriceX96` value.
     */
    function _decodeSqrtPriceX96(address underlying, uint underlyingDecimalsScaler, uint sqrtPriceX96) private view returns (uint price) {
        if (uint160(underlying) < uint160(address(WETH))) {
            price = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, uint(2 ** (96 * 2)) / 1e18) / underlyingDecimalsScaler;
        } else {
            price = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, uint(2 ** (96 * 2)) / (1e18 * underlyingDecimalsScaler));
            if (price == 0) return 1e36;
            price = 1e36 / price;
        }

        if (price > 1e36) price = 1e36;
        else if (price == 0) price = 1;
    }

    /**
     * This means that this function essentially acts as an intermediary function that just
     * subsequently calls `_getPrice` for each token passed. Not really gas efficient, but
     * unfortunately the best we can do with what we have.
     */
    function _getPrices(address[] calldata tokens) internal returns (uint[] memory) {
        uint[] memory prices = new uint[](tokens.length);
        for (uint i; i < tokens.length;) {
            prices[i] = _getPrice(tokens[i]);
            unchecked {
                ++i;
            }
        }
        return prices;
    }

    /**
     * Gas efficient revert.
     */
    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length > 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }

        revert('e/empty-error');
    }
}
