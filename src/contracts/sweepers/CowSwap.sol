// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {GPv2Order} from 'cowprotocol/libraries/GPv2Order.sol';

import {ComposableCoW} from '@composable-cow/ComposableCoW.sol';
import {IConditionalOrder} from '@composable-cow/interfaces/IConditionalOrder.sol';
import {TWAP} from '@composable-cow/types/twap/TWAP.sol';
import {TWAPOrder} from '@composable-cow/types/twap/libraries/TWAPOrder.sol';
import {ERC1271Forwarder} from '@composable-cow/ERC1271Forwarder.sol';

import {FullMath} from '@uniswap-v3/v3-core/contracts/libraries/FullMath.sol';
import {TickMath} from '@uniswap-v3/v3-core/contracts/libraries/TickMath.sol';
import {IUniswapV3Pool} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {FixedPoint96} from "@uniswap-v3/v3-core/contracts/libraries/FixedPoint96.sol";

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';


/**
 * ..
 */
contract CowSwapSweeper is ISweeper, ERC1271Forwarder {
    using GPv2Order for *;

    struct Pool {
        address pool;       // Address of the UV3 pool
        uint16 slippage;    // % of slippage to 1dp accuracy
    }

    /// ..
    ComposableCoW composableCow;
    TWAP twap;

    /// The address of our {Treasury} that will receive assets
    address payable immutable treasury;
    address immutable relayer;
    IWETH immutable weth;

    /// ..
    bytes32 constant public salt = keccak256('floordao.cowswap.twap');

    constructor (
        address payable _treasury,
        address _relayer,
        address _composableCow,
        address _twapHandler
    ) ERC1271Forwarder(ComposableCoW(_composableCow)) {
        treasury = _treasury;

        composableCow = ComposableCoW(_composableCow);
        twap = TWAP(_twapHandler);
        relayer = _relayer;

        weth = ITreasury(treasury).weth();
    }

    /**
     * ..
     */
    function execute(address[] calldata _collections, uint[] calldata _amounts, bytes calldata data)
        external
        payable
        override
        returns (string memory)
    {
        Pool[] memory pool = abi.decode(data, (Pool[]));

        for (uint i; i < _collections.length;) {
            // Determine our buy token
            address buyToken = IUniswapV3Pool(pool[i].pool).token0();
            if (buyToken == address(weth)) {
                buyToken = IUniswapV3Pool(pool[i].pool).token1();
            }

            // Get the Uniswap pool TWAP price
            uint spotPriceWithSlippage = FullMath.mulDiv(
                _getPriceFromSqrtPriceX96(buyToken, 10 ** (18 - IERC20Metadata(buyToken).decimals()), _getSqrtTwapX96(pool[i].pool, 300)),
                1000,
                1000 - pool[i].slippage
            );

            // Create and sign
            _placeOrder(buyToken, _amounts[i], spotPriceWithSlippage);

            unchecked { ++i; }
        }

        return '';
    }

    function _placeOrder(address buyToken, uint sellAmount, uint buyAmount) internal {
        // Assumptions:
        // The Safe has already had its fallback handler set to ExtensibleFallbackHandler.
        // The Safe has set the domainVerifier for the GPv2Settlement.domainSeparator() to ComposableCoW

        /**
         * To create a TWAP order:
         *
         * ABI-Encode the IConditionalOrder.ConditionalOrderParams struct with:
         *  handler: set to the TWAP smart contract deployment.
         *  salt: set to a unique value.
         *  staticInput: the ABI-encoded TWAP.Data struct.
         *
         * Use the struct from (1) as either a Merkle leaf, or with ComposableCoW.create to create a single conditional order.
         *
         * Approve GPv2VaultRelayer to trade n x partSellAmount of the safe's sellToken tokens (in the example above, GPv2VaultRelayer would receive approval for spending 12,000,000 DAI tokens).
         *
         * NOTE: When calling ComposableCoW.create, setting dispatch = true will cause ComposableCoW to emit event logs that are indexed by the watch tower automatically. If you wish to maintain a private order (and will submit to the CoW Protocol API through your own infrastructure, you may set dispatch to false).
         */

        uint32 FREQUENCY = 1 hours;
        uint32 NUM_PARTS = 12;
        uint32 SPAN = 5 minutes;
        uint LIMIT_PRICE = buyAmount / NUM_PARTS;

        // authorize the vault relayer to pull the sell token from the safe
        weth.approve(relayer, sellAmount);

        composableCow.create({
            params: IConditionalOrder.ConditionalOrderParams({
                handler: twap,
                salt: salt,
                staticInput: abi.encode(
                    TWAPOrder.Data({
                        sellToken: weth,
                        buyToken: IERC20(buyToken),
                        receiver: address(treasury),
                        partSellAmount: sellAmount / NUM_PARTS,
                        minPartLimit: LIMIT_PRICE,
                        t0: block.timestamp + 60,
                        n: NUM_PARTS,
                        t: FREQUENCY,
                        span: SPAN,
                        appData: salt
                    })
                )
            }),
            dispatch: true
        });
    }

    function _getSqrtTwapX96(address uniswapV3Pool, uint32 twapInterval) internal view returns (uint160 sqrtPriceX96) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval; // from (before)
        secondsAgos[1] = 0; // to (now)

        (int56[] memory tickCumulatives,) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos);

        // tick(imprecise as it's an integer) to price
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
        );
    }

    function _getPriceFromSqrtPriceX96(address underlying, uint underlyingDecimalsScaler, uint160 sqrtPriceX96) internal view returns (uint price) {
        if (uint160(underlying) < uint160(address(weth))) {
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
     * Specify that only a TREASURY_MANAGER can run this sweeper.
     */
    function permissions() public pure override returns (bytes32) {
        return keccak256('TreasuryManager');
    }

    /**
     * Allow the contract to receive ETH back during the `endSweep` call.
     */
    receive() external payable {}
}
