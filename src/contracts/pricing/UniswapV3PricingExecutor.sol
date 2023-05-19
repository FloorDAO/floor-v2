// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {FullMath} from '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/// If we are unable to find a pool for the Uniswap token combination
error UnknownUniswapPool();

/**
 * Partial interface for the {IUniswapV3Factory} contract. The full interface can be found here:
 * https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Factory.sol
 *
 */
interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

/**
 * Partial interface for the {IUniswapV3Pool}. The full interface can be found here:
 * https://github.com/Uniswap/v3-core/blob/main/contracts/interfaces/IUniswapV3Pool.sol
 */
interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
    function liquidity() external view returns (uint128);
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives);
    function observations(uint index)
        external
        view
        returns (uint32 blockTimestamp, int56 tickCumulative, uint160 liquidityCumulative, bool initialized);
}

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
contract UniswapV3PricingExecutor is IBasePricingExecutor {
    /// Maintain an immutable address of the Uniswap V3 Pool Factory contract
    IUniswapV3Factory public immutable uniswapV3PoolFactory;

    /// The contract address of the Floor token
    address public immutable floor;

    /// The WETH contract address used for price mappings
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// Keep a cache of our pool addresses for gas optimisation
    mapping(address => address) internal poolAddresses;

    /// Keep a cache of our latest price mappings
    mapping(address => uint) internal floorPriceCache;

    /**
     * Set our immutable contract addresses.
     *
     * @dev Mainnet Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984
     */
    constructor(address _poolFactory, address _floor) {
        uniswapV3PoolFactory = IUniswapV3Factory(_poolFactory);
        floor = _floor;
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
    function getETHPrices(address[] memory tokens) external returns (uint[] memory) {
        return _getPrices(tokens);
    }

    /**
     * Gets a live mapped price of a token to FLOOR, returned in the correct decimal
     * count for the target token.
     *
     * We get the latest price of not only the requested token, but also for the
     * FLOOR token. We can then determine the amount of returned token based on
     * live price values from Token -> ETH -> FLOOR.
     *
     * @param token Token to find price of
     *
     * @return uint The FLOOR value of a singular token
     */
    function getFloorPrice(address token) external returns (uint) {
        // Send our token address, as well as our FLOOR address
        address[] memory tokens = new address[](2);
        tokens[0] = token;
        tokens[1] = address(floor);

        // Get our token prices and find the converted value into FLOOR
        uint[] memory prices = _getPrices(tokens);
        return floorPriceCache[token] = _calculateFloorPrice(prices[0], prices[1]);
    }

    /**
     * Gets a live mapped price of multiple tokens to FLOOR.
     *
     * @param tokens[] Tokens to find price of
     *
     * @return uint[] The FLOOR values of tokens passed
     */
    function getFloorPrices(address[] memory tokens) external returns (uint[] memory) {
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
            output[i] = _calculateFloorPrice(prices[i], floorPrice);
            floorPriceCache[tokens[i]] = output[i];
            unchecked {
                ++i;
            }
        }

        return output;
    }

    /**
     * Gets the latest Floor price returned. This won't make an external call and should
     * only be used in reference when live data is not required.
     */
    function getLatestFloorPrice(address token) external view returns (uint) {
        return floorPriceCache[token];
    }

    /**
     * Retrieves the amount of WETH held in the Uniswap pool.
     */
    function getLiquidity(address token) external returns (uint) {
        return IWETH(WETH).balanceOf(_poolAddress(token));
    }

    /**
     * This helper function allows us to return the amount of FLOOR a user would receive
     * for 1 token, returned in the decimal accuracy of the FLOOR token.
     *
     * @param tokenPrice Spot price of passed token contract for 1 token
     * @param floorPrice Spot price of FLOOR for 1 token
     *
     * @return The amount of FLOOR returned if one token sold
     */
    function _calculateFloorPrice(uint tokenPrice, uint floorPrice) internal pure returns (uint) {
        unchecked {
            if (floorPrice > tokenPrice) {
                return ((tokenPrice * 1e18) / floorPrice);
            }

            return ((tokenPrice * 1e18) / floorPrice) / 1e18;
        }
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
        if (poolAddresses[token] != address(0)) {
            return poolAddresses[token];
        }

        // Load our candidate pool
        address candidatePool = uniswapV3PoolFactory.getPool(token, WETH, 10000);

        // If we can't find a pool, then we need to raise an error
        if (candidatePool == address(0)) {
            revert UnknownUniswapPool();
        }

        // Store the token pool into our internal cache and return the address
        return poolAddresses[token] = candidatePool;
    }

    /**
     * Retrieves the token price in WETH from a Uniswap pool.
     *
     * @param token The token contract to find the ETH price of
     *
     * @return Price of the token in ETH
     */
    function _getPrice(address token) internal returns (uint) {
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
        (bool success, bytes memory data) = pool.staticcall(abi.encodeWithSelector(IUniswapV3Pool.observe.selector, secondsAgos));
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
            (success, data) = pool.staticcall(abi.encodeWithSelector(IUniswapV3Pool.observe.selector, secondsAgos));
            if (!success) revertBytes(data);
        }

        // If uniswap pool doesn't exist, then data will be empty and this decode will throw:
        int56[] memory tickCumulatives = abi.decode(data, (int56[])); // don't bother decoding the liquidityCumulatives array

        // Get our tick value from the cumulatives
        int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int(ago)));

        // Get our token price
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        // Remove our fee from this amount by our 1% fee (1000 = 1%)
        return (decodeSqrtPriceX96(token, 10 ** (18 - ERC20(token).decimals()), sqrtPriceX96) * 99000) / 100000;
    }

    /**
     * Decodes the `SqrtPriceX96` value.
     */
    function decodeSqrtPriceX96(address underlying, uint underlyingDecimalsScaler, uint sqrtPriceX96) private pure returns (uint price) {
        if (uint160(underlying) < uint160(WETH)) {
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
    function _getPrices(address[] memory tokens) internal returns (uint[] memory) {
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
