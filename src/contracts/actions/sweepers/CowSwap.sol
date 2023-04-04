// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {GATOrder} from '@floor/forks/GATOrder.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {ICoWSwapSettlement} from '@floor-interfaces/cowswap/CoWSwapSettlement.sol';
import {GPv2Order} from '@floor-interfaces/cowswap/GPv2Order.sol';
import {ICoWSwapOnchainOrders} from '@floor-interfaces/cowswap/CoWSwapOnchainOrders.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * Interacts with the CowSwap protocol to fulfill a sweep order.
 *
 * Based on codebase:
 * https://github.com/nlordell/dappcon-2022-smart-orders
 */
contract CowSwapSweeper is ICoWSwapOnchainOrders, ISweeper {
    using GPv2Order for *;

    struct Data {
        IERC20 sellToken;
        IERC20 buyToken;
        address receiver;
        uint sellAmount;
        uint buyAmount;
        uint32 validFrom;
        uint32 validTo;
        uint feeAmount;
        bytes meta;
    }

    bytes32 public constant APP_DATA = keccak256('floordao');

    ICoWSwapSettlement public immutable settlement;
    bytes32 public immutable domainSeparator;

    IWETH public immutable weth;

    address public immutable treasury;

    constructor(address settlement_, address weth_, address treasury_) {
        settlement = ICoWSwapSettlement(settlement_);
        domainSeparator = settlement.domainSeparator();
        treasury = treasury_;
        weth = IWETH(weth_);
    }

    function execute(address[] calldata collections, uint[] calldata amounts, bytes calldata /* data */) external payable override returns (string memory) {
        // Wrap out msg.value into WETH
        weth.deposit{value: msg.value}();

        // Loop through our collections
        uint length = collections.length;
        for (uint i; i < length;) {
            // Generate our order data for the collection
            GPv2Order.Data memory order = GPv2Order.Data({
                sellToken: weth,
                buyToken: IERC20(collections[i]),
                receiver: treasury,
                sellAmount: amounts[i],
                buyAmount: 0,
                validTo: uint32(block.timestamp + 3600),
                appData: APP_DATA,
                feeAmount: 0,
                kind: GPv2Order.KIND_BUY,
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

            // Transfer our sell token to CowSwap to cover the sell amount and the fee required
            order.sellToken.transferFrom(address(this), address(instance), order.sellAmount + order.feeAmount);

            // Generate our signature being used for the sweep
            OnchainSignature memory signature = OnchainSignature({scheme: OnchainSigningScheme.Eip1271, data: hex''});

            emit OrderPlacement(address(instance), order, signature, '');

            // bytes memory orderUid = new bytes(GPv2Order.UID_LENGTH);
            // orderUid.packOrderUidParams(orderHash, address(instance), order.validTo);

            unchecked { ++i; }
        }

        // Return an empty string as no message to store
        return '';
    }
}
