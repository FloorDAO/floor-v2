// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import '../../interfaces/pricing/BasePricingExecutor.sol';


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

    /**
     * Set our immutable contract addresses.
     *
     * Factory : 0x1F98431c8aD98523631AE4a59f267346ea31F984
     * Floor   : TBC
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
     * Gets our live price of a token to ETH.
     */
    function getETHPrice(address token) external returns (uint) {
        return _getPrice(token);
    }

    /**
     * Gets our live prices of multiple tokens to ETH.
     */
    function getETHPrices(address[] memory tokens) external returns (uint[] memory output) {
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
    function getFloorPrice(address token) external returns (uint) {
        address[] memory tokens = new address[](2);
        tokens[0] = token;
        tokens[1] = address(floor);

        uint[] memory prices = _getPrices(tokens);
        return _calculateFloorPrice(token, prices[0], prices[1]);
    }

    /**
     * Gets a live mapped price of multiple tokens to FLOOR.
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
            output[i] = _calculateFloorPrice(tokens[i], prices[i], floorPrice);
            unchecked { ++i; }
        }

        return output;
    }

    /**
     * This helper function allows us to return the amount of tokens a user would receive
     * for 1 FLOOR token, returned in the decimal accuracy of the base token.
     */
    function _calculateFloorPrice(address token, uint tokenPrice, uint floorPrice) internal view returns (uint) {
        return (floorPrice * (10 ** ERC20(token).decimals())) / tokenPrice;
    }

    /**
     * Returns the pool address for a given pair of tokens and a fee, or address 0 if
     * it does not exist. The secondary token will always be WETH for our requirements,
     * so this is just passed in from our contract constant.
     *
     * For gas optimisation, we cache the pool address that is calculated, to prevent
     * subsequent external calls being required.
     */
    function _poolAddress(address token, uint24 fees) internal returns (address) {
        if (poolAddresses[token] == address(0)) {
            poolAddresses[token] = uniswapV3PoolFactory.getPool(token, WETH, fees);
            require(poolAddresses[token] != address(0), 'Unknown pool');
        }

        return poolAddresses[token];
    }

    /**
     * Retrieves the token price in WETH from a Uniswap pool.
     */
    function _getPrice(address token) internal returns (uint256) {
        // We only vary our default 0.3% fees if we are dealing with our FLOOR pool, which
        // has a fee of 1% instead.
        uint24 fees = token == floor ? 10000 : 3000;

        // We can get the cached / fresh pool address for our token <-> WETH pool. If the
        // pool doesn't exist then this function will revert our tx.
        address poolAddress = _poolAddress(token, fees);

        // We set our TWAP range to 30 minutes
        uint32[] memory secondsAgos = new uint32[](2);
        (secondsAgos[0], secondsAgos[1]) = (1800, 0);

        // We can now observe the Uniswap pool to get our tick
        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(poolAddress).observe(secondsAgos);

        // We can now use the tick to calculate how much WETH we would receive from swapping
        // 1 token.
        return _getQuoteAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / 1800),
            uint128(10 ** ERC20(token).decimals()),
            token,
            WETH
        );
    }

    /**
     * Unfortunately we aren't able to use Uniswap multicall to group our requests in this
     * instance as we are actually calling different contracts based on the constructor.
     *
     * This means that this function essentially acts as an intermediary function that just
     * subsequently calls `_getPrice` for each token passed. Not really gas efficient, but
     * unfortunately the best we can do with what we have.
     */
    function _getPrices(address[] memory tokens) internal returns (uint256[] memory) {
        uint[] memory prices = new uint[](tokens.length);
        for (uint i; i < tokens.length;) {
            prices[i] = _getPrice(tokens[i]);
            unchecked { ++i; }
        }
        return prices;
    }

    /**
     * Given a tick and a token amount, calculates the amount of token received in exchange.
     *
     * @param tick Tick value used to calculate the quote
     * @param baseAmount Amount of token to be converted
     * @param baseToken Address of an ERC20 token contract used as the baseAmount denomination
     * @param quoteToken Address of an ERC20 token contract used as the quoteAmount denomination
     *
     * @return quoteAmount Amount of quoteToken received for baseAmount of baseToken
     */
    function _getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

}
