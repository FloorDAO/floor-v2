// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';

import {GATOrder} from '@floor/forks/GATOrder.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {ICoWSwapSettlement} from '@floor-interfaces/cowswap/CoWSwapSettlement.sol';
import {GPv2Order} from '@floor-interfaces/cowswap/GPv2Order.sol';
import {ICoWSwapOnchainOrders} from '@floor-interfaces/cowswap/CoWSwapOnchainOrders.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * Interacts with the CowSwap protocol to create an order.
 *
 * Based on codebase:
 * https://github.com/nlordell/dappcon-2022-smart-orders
 */
contract CowSwapCreateOrder is IAction, ICoWSwapOnchainOrders, Pausable {
    using GPv2Order for *;

    /// @dev The complete data for a Gnosis Protocol order. This struct contains
    /// all order parameters that are signed for submitting to GP.
    struct ActionRequest {
        address sellToken;
        address buyToken;
        address receiver;
        uint sellAmount;
        uint buyAmount;
        uint feeAmount;
    }

    /// Encoded app data to recognise our transactions
    bytes32 public constant APP_DATA = keccak256('floordao');

    /// Stores the external {CowSwapSettlement} contract reference
    /// @dev Mainnet implementation: 0x9008d19f58aabd9ed0d60971565aa8510560ab41
    ICoWSwapSettlement public immutable settlement;

    /// Domain separator taked from the settlement contract
    bytes32 public immutable domainSeparator;

    /// Constant address of the WETH token
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * Sets up our {CowSwapSettlement} contract reference
     */
    constructor(address settlement_) {
        settlement = ICoWSwapSettlement(settlement_);
        domainSeparator = settlement.domainSeparator();
    }

    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        /**
         * Do not sign orders with simultaneously sellAmount == 0, buyAmount == 0, and
         * partiallyFillable == false. Because of a known issue in the contracts, such orders
         * can be settled unlimited times, which means that any solver could take the fee
         * amount multiple times. There is normally no reason to generate such "empty" order.
         *
         * However, you should consider this case if you are signing orders that come from
         * potentially untrusted sources.
         */
        require(request.buyAmount + request.sellAmount > 0);

        // Wrap our msg.value into WETH if that is our sell token
        if (request.sellToken == weth) {
            IWETH(weth).deposit{value: request.sellAmount}();
        }

        // Approve the vault relayer to use our tokens when needed
        IERC20(request.sellToken).approve(settlement.vaultRelayer(), type(uint).max);

        // Generate our order data for the collection
        GPv2Order.Data memory order = GPv2Order.Data({
            sellToken: IERC20(request.sellToken),
            buyToken: IERC20(request.buyToken),
            receiver: request.receiver,
            sellAmount: request.sellAmount,
            buyAmount: request.buyAmount,
            validTo: uint32(block.timestamp + 3600),
            appData: APP_DATA,
            feeAmount: request.feeAmount,
            kind: GPv2Order.KIND_SELL,
            partiallyFillable: false,
            sellTokenBalance: GPv2Order.BALANCE_ERC20,
            buyTokenBalance: GPv2Order.BALANCE_ERC20
        });

        // Hash our order, based on our `domainSeparator`
        bytes32 orderHash = order.hash(domainSeparator);

        // Create our order instance
        GATOrder instance = new GATOrder{salt: bytes32('salt')}(
            address(this),
            order.sellToken,
            uint32(block.timestamp),
            orderHash,
            settlement
        );

        // Generate our signature being used for the limit order creation
        OnchainSignature memory signature = OnchainSignature({scheme: OnchainSigningScheme.Eip1271, data: hex''});

        emit OrderPlacement(address(instance), order, signature, '');

        // Return an empty string as no message to store
        return 0;
    }
}
