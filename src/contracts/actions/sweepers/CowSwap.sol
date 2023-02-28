// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';

import {ISweeper} from '../../../interfaces/actions/Sweeper.sol';
import {ICoWSwapSettlement} from '../../../interfaces/cowswap/CoWSwapSettlement.sol';
import {GPv2Order} from '../../../interfaces/cowswap/GPv2Order.sol';
import {ICoWSwapOnchainOrders} from '../../../interfaces/cowswap/CoWSwapOnchainOrders.sol';
import {IWETH} from '../../../interfaces/tokens/WETH.sol';

/// https://github.com/nlordell/dappcon-2022-smart-orders
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

    bytes32 public constant APP_DATA = keccak256('smart orders are cool');

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

    function execute(address[] memory collections, uint[] memory amounts) external payable override returns (bytes memory orderUid) {
        // Wrap out msg.value into WETH
        weth.deposit{value: msg.value}();

        // Loop through our collections
        for (uint i; i < collections.length; ++i) {
            GPv2Order.Data memory order = GPv2Order.Data({
                sellToken: weth,
                buyToken: IERC20(collections[i]),
                receiver: treasury,
                sellAmount: amounts[i],
                buyAmount: 0,
                validTo: uint32(block.timestamp + 3600),
                appData: APP_DATA,
                feeAmount: 0,
                kind: GPv2Order.KIND_SELL,
                partiallyFillable: false,
                sellTokenBalance: GPv2Order.BALANCE_ERC20,
                buyTokenBalance: GPv2Order.BALANCE_ERC20
            });

            bytes32 orderHash = order.hash(domainSeparator);

            GATOrder instance = new GATOrder{salt: bytes32('salt')}(
                address(this),
                order.sellToken,
                uint32(block.timestamp),
                orderHash,
                settlement
            );

            order.sellToken.transferFrom(address(this), address(instance), order.sellAmount + order.feeAmount);

            OnchainSignature memory signature = OnchainSignature({scheme: OnchainSigningScheme.Eip1271, data: hex''});

            emit OrderPlacement(address(instance), order, signature, ''); // TODO: 4th param is meta?

            orderUid = new bytes(GPv2Order.UID_LENGTH);
            orderUid.packOrderUidParams(orderHash, address(instance), order.validTo);
        }
    }
}

contract GATOrder is IERC1271 {
    address public immutable owner;
    IERC20 public immutable sellToken;
    uint32 public immutable validFrom;

    bytes32 public orderHash;

    constructor(address owner_, IERC20 sellToken_, uint32 validFrom_, bytes32 orderHash_, ICoWSwapSettlement settlement) {
        owner = owner_;
        sellToken = sellToken_;
        validFrom = validFrom_;
        orderHash = orderHash_;

        sellToken_.approve(settlement.vaultRelayer(), type(uint).max);
    }

    function isValidSignature(bytes32 hash, bytes calldata) external view returns (bytes4 magicValue) {
        require(hash == orderHash, 'invalid order');
        require(block.timestamp >= validFrom, 'not mature');
        magicValue = 0x1626ba7e; // ERC1271_MAGIC_VALUE
    }

    function cancel() public {
        require(msg.sender == owner, 'not the owner');
        orderHash = bytes32(0);
        sellToken.transfer(owner, sellToken.balanceOf(address(this)));
    }
}
