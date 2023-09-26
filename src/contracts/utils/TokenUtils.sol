// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * `TokenUtils` library forked from DefiSaver and manipulated to better suit the
 * Floor codebase and also in reflection of code audit.
 */
library TokenUtils {
    using SafeERC20 for IERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function approveToken(address _tokenAddr, address _to, uint _amount) internal {
        // Native token won't require approval
        if (_tokenAddr == ETH_ADDR) return;

        // If we don't already have sufficient allowance, we can increase our approval
        if (IERC20(_tokenAddr).allowance(address(this), _to) < _amount) {
            // Certain tokens, such as USDT, will fail when attempting to assign a non-zero
            // approval whilst one exists.
            IERC20(_tokenAddr).approve(_to, 0);
            IERC20(_tokenAddr).approve(_to, _amount);
        }
    }

    function pullTokensIfNeeded(address _token, address _from, uint _amount) internal returns (uint) {
        // If we are pulling native tokens, we need to ensure that the `msg.value` is sufficient
        if (_token == ETH_ADDR) {
            require(msg.value >= _amount, 'Insufficient ETH');
            _amount = msg.value;
        }
        else if (_from != address(0) && _from != address(this) && _amount != 0) {
            // If a max amount if requested, then we convert to the entire balance
            if (_amount == type(uint).max) {
                _amount = getBalance(_token, _from);
            }

            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        }

        return _amount;
    }

    function withdrawTokens(address _token, address _to, uint _amount) internal returns (uint) {
        if (_amount == type(uint).max) {
            _amount = getBalance(_token, address(this));
        }

        if (_to != address(0) && _to != address(this) && _amount != 0) {
            if (_token != ETH_ADDR) {
                IERC20(_token).safeTransfer(_to, _amount);
            } else {
                (bool success,) = _to.call{value: _amount}('');
                require(success, 'Eth send fail');
            }
        }

        return _amount;
    }

    function getBalance(address _tokenAddr, address _acc) internal view returns (uint) {
        if (_tokenAddr == ETH_ADDR) {
            return _acc.balance;
        } else {
            return IERC20(_tokenAddr).balanceOf(_acc);
        }
    }
}
