// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC1271} from '@openzeppelin/contracts/interfaces/IERC1271.sol';

import {CannotSetNullAddress} from '@floor/utils/Errors.sol';

import {ICoWSwapSettlement} from '@floor-interfaces/cowswap/CoWSwapSettlement.sol';

contract GATOrder is IERC1271 {
    address public immutable owner;
    IERC20 public immutable sellToken;
    uint32 public immutable validFrom;

    bytes32 public orderHash;

    constructor(address owner_, IERC20 sellToken_, uint32 validFrom_, bytes32 orderHash_, ICoWSwapSettlement settlement) {
        if (owner_ == address(0) || address(sellToken_) == address(0)) revert CannotSetNullAddress();

        owner = owner_;
        sellToken = sellToken_;
        validFrom = validFrom_;
        orderHash = orderHash_;

        sellToken_.approve(settlement.vaultRelayer(), type(uint).max);
    }

    function isValidSignature(bytes32 hash, bytes calldata) external view override returns (bytes4 magicValue) {
        require(hash == orderHash, 'invalid order');
        require(block.timestamp >= validFrom, 'not mature');
        magicValue = IERC1271.isValidSignature.selector;
    }

    function cancel() public {
        require(msg.sender == owner, 'not the owner');
        orderHash = bytes32(0);
        sellToken.transfer(owner, sellToken.balanceOf(address(this)));
    }
}
