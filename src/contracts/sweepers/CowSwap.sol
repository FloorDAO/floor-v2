// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICoWSwapSettlement } from "./interfaces/ICoWSwapSettlement.sol";
import { ERC1271_MAGIC_VALUE, IERC1271 } from "./interfaces/IERC1271.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { GPv2Order } from "./vendored/GPv2Order.sol";
import { ICoWSwapOnchainOrders } from "./vendored/ICoWSwapOnchainOrders.sol";

import {FullMath} from '@uniswap-v3/v3-core/contracts/libraries/FullMath.sol';
import {TickMath} from '@uniswap-v3/v3-core/contracts/libraries/TickMath.sol';
import {IUniswapV3Pool} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {FixedPoint96} from "@uniswap-v3/v3-core/contracts/libraries/FixedPoint96.sol";

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {ISwapRouter} from '@floor-interfaces/uniswap/ISwapRouter.sol';


/**
 * ..
 */
contract CowSwapSweeper is ISweeper, ERC1271Forwarder {
    using GPv2Order for *;

    struct Pool {
        address pool;       // Address of the UV3 pool
        address token;      // Token being swept
        uint16 slippage;    // % of slippage to 1dp accuracy
    }

    /// ..
    ComposableCoW composableCow;
    TWAP twap;

    ICoWSwapSettlement immutable public settlement;

    /// The address of our {Treasury} that will receive assets
    address payable immutable treasury;
    address payable immutable swapRouter;
    WETH immutable weth;

    /// ..
    bytes32 constant public salt = keccak256('floordao.cowswap.twap');

    constructor (
        address payable _treasury,
        address _settlement,
        address _composableCow,
        address _twapHandler
    ) ERC1271Forwarder(_composableCow) {
        treasury = _treasury;

        composableCow = ComposableCoW(_composableCow);
        twap = TWAP(_twapHandler);
        settlement = ICoWSwapSettlement(_settlement);

        weth = treasury.WETH();
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
            // Get the Uniswap pool TWAP price
            uint spotPriceWithSlippage = FullMath.mulDiv(
                _getPriceX96FromSqrtPriceX96(_getSqrtTwapX96(pool[i].pool, 300)),
                1000,
                pool[i].slippage
            );

            // Create and sign
            _placeOrder(pool, amounts[i], spotPriceWithSlippage);

            unchecked { ++i; }
        }

        return '';
    }

    function _placeOrder(Pool memory pool, uint sellAmount, uint buyAmount) internal {
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

        uint32 constant FREQUENCY = 1 hours;
        uint32 constant NUM_PARTS = 24;
        uint32 constant SPAN = 5 minutes;
        uint256 constant LIMIT_PRICE = buyAmount / NUM_PARTS;

        // authorize the vault relayer to pull the sell token from the safe
        sellToken.approve(address(settlement.vaultRelayer()), sellAmount);

        composableCow.create({
            params: IConditionalOrder.ConditionalOrderParams({
                handler: twap,
                salt: salt,
                staticInput: abi.encode(
                    TWAPOrder.Data({
                        sellToken: address(weth),
                        buyToken: pool.token,
                        receiver: address(treasury), // the safe itself
                        partSellAmount: sellAmount / NUM_PARTS,
                        minPartLimit: LIMIT_PRICE,
                        t0: block.timestamp + 60, // start in 1 minute
                        n: NUM_PARTS,
                        t: FREQUENCY,
                        span: SPAN,
                        appData: salt
                    })
                )
            }),
            dispatch: true
        });

        return ;
    }

    function _getSqrtTwapX96(address uniswapV3Pool, uint32 twapInterval) internal view returns (uint160 sqrtPriceX96) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapInterval; // from (before)
        secondsAgos[1] = 0; // to (now)

        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(uniswapV3Pool).observe(secondsAgos);

        // tick(imprecise as it's an integer) to price
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)))
        );
    }

    function _getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) internal pure returns(uint256 priceX96) {
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
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
