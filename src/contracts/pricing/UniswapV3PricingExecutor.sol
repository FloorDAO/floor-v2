// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import '../../interfaces/pricing/BasePricingExecutor.sol';

import "forge-std/console.sol";


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

    /// Maintain an immutable address of the Uniswap V3 Quoter contract
    IUniswapV3Factory public immutable uniswapV3PoolFactory;

    /// The contract address of the Floor token
    address public immutable floor;

    /// The ETH contract address used for UV3 path generation
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The UV3 quoted price of the token
    mapping(address => uint) internal tokenPrices;

    /// The timestamp of the last time the token was run
    mapping(address => uint) internal tokenPriceFreshness;

    /// Keep a cache of our pool addresses
    mapping(address => address) internal poolAddresses;

    /**
     * Set our immutable contract addresses.
     *
     * Quoter : 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6
     * Floor  : TBC
     */
    constructor (address _quoter, address _floor) {
        uniswapV3PoolFactory = IUniswapV3Factory(_quoter);
        floor = _floor;
    }

    /**
     * Name of the pricing executor.
     */
    function name() external pure returns (string memory) {
        return 'UniswapV3PricingExecutor';
    }

    /**
     * Gets our current mapped price of a token to ETH.
     */
    function getETHPrice(address token) external returns (uint) {
        return _getPrice(token);
    }

    /**
     * Gets our current mapped price of multiple tokens to ETH.
     */
    function getETHPrices(address[] memory tokens) external returns (uint[] memory output) {
        return _getPrices(tokens);
    }

    /**
     * Gets our current mapped price of a token to FLOOR.
     *
     * X -> ETH = Xe = 10 ETH
     * Y -> ETH = Ye = 0.5 ETH
     * X -> Y = Xe / Ye = 20
     */
    function getFloorPrice(address token) external returns (uint) {
        (uint Xe, uint Ye) = _getPrices([token, address(floor)]);
        return Xe / Ye;
    }

    /**
     * Gets our current mapped price of multiple tokens to FLOOR.
     */
    function getFloorPrices(address[] memory tokens) external returns (uint[] memory output) {
        // Get floor once
        uint floorPrice = _getPrice(address(floor));
        uint[] memory prices = _getPrices(tokens);

        for (uint i; i < prices.length;) {
            output[i] = prices[i] / floorPrice;
            unchecked { ++i; }
        }
    }

    /**
     * Gets the timestamp of when the price was last updated by the executor.
     */
    function getPriceFreshness(address token) external view returns (uint) {
        return tokenPriceFreshness[token];
    }


    /**
     * Returns the pool address for a given pair of tokens and a fee, or address 0
     * if it does not exist.
     *
     * tokenA and tokenB may be passed in either token0/token1 or token1/token0 order.
     */
    function _poolAddress(address token, uint24 fees) internal view returns (address) {
        if (poolAddresses[token] == address(0)) {
            poolAddresses[token] = uniswapV3PoolFactory.getPool(token, WETH, fees);
            require(poolAddresses[token] != address(0));
        }

        return poolAddresses[token];
    }


    /**
     * Quoter is only available for off-chain. The gas cost was insanely high and took
     * a very long time to process.
     *
     * - Do we only want to have a twapInterval of 0 to get the latest price?
     * - How can we map a pool against a token0 and token1?
     * - How do we determine the best fees to use?
     * - Can we implement multicall for multiple observes?
     * - We will need to remove paths and implement X -> ETH and ETH -> Y
     *
     */



    function _getPrice(address token) internal view returns (uint256) {
        uint32 twapInterval = 0;
        address poolAddress = _poolAddress(token, 3000);

        if (twapInterval == 0) {
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(poolAddress).slot0();
            return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval;
            secondsAgos[1] = 0;
            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(poolAddress).observe(secondsAgos);
            uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24((tickCumulatives[1] - tickCumulatives[0]) / twapInterval)
            );
            return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
        }
    }


    /**
     * User multicall to faciltate multiple price TWAP calls.
     *
     * I don't think we can use multicall in this instance as we are calling different
     * contracts based on the constructor.
     */
    function _getPrices(address[] memory tokens) internal view returns (uint256[] memory prices) {
        for (uint i; i < tokens.length;) {
            prices[i] = _getPrice(tokens[i]);
            unchecked { ++i; }
        }
    }


    /**
     * Updates our price of a token in ETH value.
     *
     * To update the price, we will want to `observe` the `UniswapV3Pool`:
     * https://docs.uniswap.org/protocol/reference/core/UniswapV3Pool#observe
     */
    /*
    function _getPriceOld(bytes memory path) internal returns (uint) {
        try uniswapV3Quoter.quoteExactInput(path, 1 ether) {
            // ..
        } catch (bytes memory reason) {
            (uint a,,) = abi.decode(reason, (uint256, uint160, int24));
            return a;
        }

        return 0;
    }
    */

}
