// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {GPv2Order} from 'cowprotocol/libraries/GPv2Order.sol';

import {ComposableCoW} from '@composable-cow/ComposableCoW.sol';
import {IConditionalOrder} from '@composable-cow/interfaces/IConditionalOrder.sol';
import {IValueFactory} from '@composable-cow/interfaces/IValueFactory.sol';
import {TWAP, TWAPOrder} from '@composable-cow/types/twap/TWAP.sol';
import {TWAPOrderMathLib} from '@composable-cow/types/twap/libraries/TWAPOrderMathLib.sol';
import {ERC1271Forwarder} from '@composable-cow/ERC1271Forwarder.sol';

import {FullMath} from '@uniswap-v3/v3-core/contracts/libraries/FullMath.sol';
import {TickMath} from '@uniswap-v3/v3-core/contracts/libraries/TickMath.sol';
import {IUniswapV3Pool} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';


/**
 * This sweeper uses the CowSwap protocol to create ERC20 Buy Orders. It protects
 * against MEV sandwich attacks and allows us to use a calculated onchain price for
 * the token using a TWAP on Uniswap V3.
 *
 * Orders will be filled over time, and competing fillers will strive to get the
 * best possible price. This is beneficial over traditional exact swaps.
 */
contract CowSwapSweeper is AuthorityControl, ISweeper, ERC1271Forwarder {
    using GPv2Order for *;

    /// Register event that is emitted when new sweep is created
    event CowSwapOrderCreated(PoolExit _poolExit);

    /// The pool structure is required for price acquisition and set per call
    struct Pool {
        address pool;     // Address of the UV3 pool
        uint24 fee;       // The UV3 pool fee
        uint16 slippage;  // % of slippage to 1dp accuracy
        uint32 partSize;  // The ETH size per part for fills
    }

    /// Information to allow for WETH withdrawal
    struct PoolExit {
        uint192 maxAmount;
        uint64 unlockTimestamp;
    }

    /// CowSwap related contract addresses
    ComposableCoW public immutable composableCow;
    TWAP public immutable twap;
    address public immutable relayer;

    /// The address of our {Treasury} that will receive assets
    address payable public immutable treasury;
    IWETH public immutable weth;

    /// Our unique salt used to index orders
    bytes32 constant public salt = keccak256('floordao.cowswap.twap');

    /// Our appData hash
    /// @dev Generated from https://learn.cow.fi/tutorial/orderbook-upload-app-data
    bytes32 public appDataHash = 0x112e2f400135ed78bac3dcbdd24389bd3afb029cc0ed7cefa6b1f71008ac36ec;

    /// Maintain a mapping of swap values for WETH rescue
    mapping (bytes32 => PoolExit) public swaps;

    /**
     * Registers a range of CowSwap contracts and our internal {Treasury} contract as
     * this will receive any purchased tokens.
     *
     * @param _treasury Our {Treasury} contract
     * @param _relayer The contract to approve WETH against that will route our WETH
     * @param _composableCow The ComposableCoW contract that handles order creation
     * @param _twapHandler The TWAP contract that structures our order
     */
    constructor (
        address _authority,
        address payable _treasury,
        address _relayer,
        address _composableCow,
        address _twapHandler
    ) AuthorityControl(_authority) ERC1271Forwarder(ComposableCoW(_composableCow)) {
        // Set our {Treasury} address and extract the network WETH address
        treasury = _treasury;
        weth = ITreasury(treasury).weth();

        // Set up our CowSwap contracts
        composableCow = ComposableCoW(_composableCow);
        twap = TWAP(_twapHandler);
        relayer = _relayer;

        // Approve our relayer to use the WETH in this contract
        weth.approve(relayer, type(uint).max);
    }

    /**
     * Iterates over our collections and creates a number of orders.
     *
     * We also deposit any received ETH into WETH to facilitate the full order values.
     */
    function execute(address[] calldata _collections, uint[] calldata _amounts, bytes calldata data)
        external
        payable
        override
        returns (string memory)
    {
        // Extract our Pool information from the bytes data
        Pool[] memory pool = abi.decode(data, (Pool[]));

        // Wrap any ETH received into WETH for the contract
        weth.deposit{value: msg.value}();

        // Iterate over our collections to set
        for (uint i; i < _collections.length;) {
            // Determine our buy token from the UV3 pool
            address buyToken = IUniswapV3Pool(pool[i].pool).token0();
            if (buyToken == address(weth)) {
                buyToken = IUniswapV3Pool(pool[i].pool).token1();
            }

            // Get the Uniswap pool TWAP price to determine a minumum output price
            // when factoring in the slippage amount.
            uint spotPriceWithSlippage = FullMath.mulDiv(
                _getPriceFromSqrtPriceX96(
                    buyToken,
                    10 ** (18 - IERC20Metadata(buyToken).decimals()),
                    _getSqrtTwapX96(pool[i].pool, pool[i].fee)
                ),
                1000 - pool[i].slippage,
                1000
            );

            // Determine the number of parts that our sweep will be divided into. For a
            // TWAPOrder to be created, we are required to have at least 2 parts, so we
            // make an explicit check for this scenario.
            uint32 numberOfParts = uint32(_amounts[i] / (uint(pool[i].partSize) * 1e16)) + 1;
            if (numberOfParts < 2) {
                numberOfParts = 2;
            }

            // Create our CowSwap TWAP order
            _placeOrder(buyToken, _amounts[i], spotPriceWithSlippage, numberOfParts);

            unchecked { ++i; }
        }

        return '';
    }

    /**
     * Places a CowSwap TWAP order.
     *
     * Assumptions:
     *  - The Safe has already had its fallback handler set to ExtensibleFallbackHandler.
     *  - The Safe has set the domainVerifier for the GPv2Settlement.domainSeparator() to ComposableCoW
     *
     * @param _buyToken The token address being purchased
     * @param _sellAmount The amount of WETH being sold to fill the order
     * @param _buyAmount The minimum amount of `_buyToken` to buy in the order
     */
    function _placeOrder(
        address _buyToken,
        uint _sellAmount,
        uint _buyAmount,
        uint32 _numberOfParts
    ) internal {
        // Build our TWAP order data
        TWAPOrder.Data memory twapOrder = TWAPOrder.Data({
            sellToken: weth,
            buyToken: IERC20(_buyToken),
            receiver: address(treasury),
            partSellAmount: _sellAmount / _numberOfParts,
            minPartLimit: _buyAmount / _numberOfParts,
            t0: 0,
            n: _numberOfParts,
            t: 1 days,
            span: 0,  // We want to action the sweep all day
            appData: appDataHash
        });

        // Validate our TWAP order
        TWAPOrder.validate(twapOrder);

        // Register our order params
        IConditionalOrder.ConditionalOrderParams memory orderParams = IConditionalOrder.ConditionalOrderParams({
            handler: twap,
            salt: salt,
            staticInput: abi.encode(twapOrder)
        });

        // Create our CowSwap TWAP Order
        composableCow.createWithContext({
            params: orderParams,
            factory: IValueFactory(0x52eD56Da04309Aca4c3FECC595298d80C2f16BAc),
            data: '',
            dispatch: true
        });

        // Register our orders internally so that we can rescue WETH if needed
        bytes32 orderHash = composableCow.hash(orderParams);
        emit CowSwapOrderCreated(
            swaps[orderHash] = PoolExit({
                maxAmount: uint192(_sellAmount),
                unlockTimestamp: uint64(TWAPOrderMathLib.calculateValidTo(block.timestamp, twapOrder.n, twapOrder.t, twapOrder.span))
            })
        );
    }

    /**
     * Allows an approved strategy manager to update our appData hash passed in our order.
     *
     * @param _appDataHash Our new `appDataHash` value
     */
    function setAppDataHash(bytes32 _appDataHash) public onlyRole(STRATEGY_MANAGER) {
        appDataHash = _appDataHash;
    }

    /**
     * Allows a caller to remove expired order WETH. The order must have expired and we cannot
     * valid the order spend, so this must be calculated off-chain.
     *
     * @param _orderHash The hash of the order to withdraw against
     * @param _amount The amount of WETH to claim back from the order
     */
    function rescueWethFromOrder(bytes32 _orderHash, uint _amount) public onlyRole(STRATEGY_MANAGER) {
        // Ensure that this contract is the owner
        PoolExit memory poolExit = swaps[_orderHash];
        require(poolExit.maxAmount != 0, 'Invalid order hash');

        // Now that we have it stored, delete the existing data to prevent reentrancy concerns
        delete swaps[_orderHash];

        // Ensure that the amount requested is less than the max
        require(_amount <= poolExit.maxAmount, 'Withdraw amount too high');

        // Load our order check the expiry time
        require(block.timestamp >= poolExit.unlockTimestamp, 'Withdraw not unlocked');

        // Transfer the amount of WETH back to the {Treasury}
        weth.transfer(treasury, _amount);
    }

    /**
     * Retrieves the token price in WETH from a Uniswap pool.
     */
    function _getSqrtTwapX96(address _uniswapV3Pool, uint32 _twapInterval) internal view returns (uint160 sqrtPriceX96) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = _twapInterval; // from (before)

        (int56[] memory tickCumulatives,) = IUniswapV3Pool(_uniswapV3Pool).observe(secondsAgos);

        // tick(imprecise as it's an integer) to price
        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(_twapInterval)))
        );
    }

    /**
     * Decodes the `SqrtPriceX96` value.
     */
    function _getPriceFromSqrtPriceX96(address _underlying, uint _underlyingDecimalsScaler, uint160 _sqrtPriceX96) internal view returns (uint price) {
        if (uint160(_underlying) < uint160(address(weth))) {
            price = FullMath.mulDiv(_sqrtPriceX96, _sqrtPriceX96, uint(2 ** (96 * 2)) / 1e18) / _underlyingDecimalsScaler;
        } else {
            price = FullMath.mulDiv(_sqrtPriceX96, _sqrtPriceX96, uint(2 ** (96 * 2)) / (1e18 * _underlyingDecimalsScaler));
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
