// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../interfaces/pricing/BasePricingExecutor.sol';
import '../../interfaces/uniswap/Quoter.v3.sol';

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
    IQuoter public immutable uniswapV3Quoter;

    /// The contract address of the Floor token
    address public immutable floor;

    /// The ETH contract address used for UV3 path generation
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The UV3 quoted price of the path
    mapping(bytes => uint) internal prices;

    /// The timestamp of the last time the path was run
    mapping(bytes => uint) internal freshness;

    /**
     * Set our immutable contract addresses.
     *
     * Quoter : 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6
     * Floor  : TBC
     */
    constructor (address _quoter, address _floor) {
        uniswapV3Quoter = IQuoter(_quoter);
        floor = _floor;

        console.logBytes(buildETHPath(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
        console.logBytes(buildFloorPath(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
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
        return _getPrice(buildETHPath(token));
    }

    /**
     * Gets our current mapped price of multiple tokens to ETH.
     */
    function getETHPrice(address[] memory token) external returns (uint[] memory output) {
        for (uint i; i < token.length;) {
            output[i] = _getPrice(buildETHPath(token[i]));
            unchecked { ++i; }
        }
    }

    /**
     * Gets our current mapped price of a token to FLOOR.
     */
    function getFloorPrice(address token) external returns (uint) {
        return _getPrice(buildFloorPath(token));
    }

    /**
     * Gets our current mapped price of multiple tokens to FLOOR.
     */
    function getFloorPrice(address[] memory token) external returns (uint[] memory output) {
        for (uint i; i < token.length;) {
            output[i] = _getPrice(buildFloorPath(token[i]));
            unchecked { ++i; }
        }
    }

    /**
     * Gets the timestamp of when the price was last updated by the executor.
     */
    function getPriceFreshness(address token) external view returns (uint) {
        return freshness[buildETHPath(token)];
    }

    /**
     * Updates our price of a token in ETH value.
     *
     * To update the price, we will want to `observe` the `UniswapV3Pool`:
     * https://docs.uniswap.org/protocol/reference/core/UniswapV3Pool#observe
     */
    function _getPrice(bytes memory path) internal returns (uint) {
        (bool success, bytes memory result) = address(uniswapV3Quoter).staticcall(abi.encodeWithSignature('quoteExactInput(bytes path,uint256 amountIn)', path, 1 ether));

        // The call is expected to be reverted, but we still want to check our returned bytes
        require(!success, 'Uniswap are gas hungry monsters');

        console.logBool(success);
        console.logBytes(result);

        return 1;
    }

    function buildETHPath(address token) internal pure returns (bytes memory) {
        return bytes.concat(
            bytes20(token),
            bytes3(uint24(3000)),
            bytes20(WETH)
        );
    }

    /**
     * ETH -> FLOOR (1%):
     * https://info.uniswap.org/#/pools/0xb386c1d831eed803f5e8f274a59c91c4c22eeac0
     */

    function buildFloorPath(address token) internal view returns (bytes memory) {
        return bytes.concat(
            buildETHPath(token),
            bytes3(uint24(10000)),
            bytes20(floor)
        );
    }

}
