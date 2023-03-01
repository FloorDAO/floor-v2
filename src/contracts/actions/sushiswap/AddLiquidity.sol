// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IUniswapV2Router01} from '@floor-interfaces/uniswap/IUniswapV2Router01.sol';

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

/**
 * ..
 *
 * @author Twade
 */
contract SushiswapAddLiquidity is IAction, Ownable, Pausable {
    using TokenUtils for address;

    struct ActionRequest {
        address tokenA;
        address tokenB;
        uint amountADesired;
        uint amountBDesired;
        uint amountAMin;
        uint amountBMin;
        address to;
        uint deadline;
    }

    /// ..
    address internal constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// ..
    IUniswapV2Router01 uniswapRouter;

    /**
     * ..
     */
    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router01(_uniswapRouter);
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        if (request.tokenA == ETH_TOKEN || request.tokenB == ETH_TOKEN) {
            require(request.tokenA != ETH_TOKEN, 'ETH token must be token B');
            return _addEthLiquidity(request);
        }

        return _addTokenLiquidity(request);
    }

    function _addEthLiquidity(ActionRequest memory request) internal returns (uint) {
        // Fetch tokens from address
        uint amountAPulled = request.tokenA.pullTokensIfNeeded(msg.sender, request.amountADesired);

        // Approve uniswapRouter so it can pull tokens
        request.tokenA.approveToken(address(uniswapRouter), amountAPulled);

        // Update our desired amounts based on the amount pulled
        request.amountADesired = amountAPulled;

        (uint amountA,, uint liquidity) = uniswapRouter.addLiquidityETH{value: msg.value}(
            request.tokenA, request.amountADesired, request.amountAMin, request.amountBMin, request.to, request.deadline
        );

        // Send leftovers
        request.tokenA.withdrawTokens(msg.sender, request.amountADesired - amountA);

        // Return any left over eth dust
        if (payable(address(this)).balance != 0) {
            (bool sent,) = msg.sender.call{value: payable(address(this)).balance}('');
            require(sent, 'Failed to refund Ether dust');
        }

        return liquidity;
    }

    function _addTokenLiquidity(ActionRequest memory request) internal returns (uint) {
        // Fetch tokens from address
        uint amountAPulled = request.tokenA.pullTokensIfNeeded(msg.sender, request.amountADesired);
        uint amountBPulled = request.tokenB.pullTokensIfNeeded(msg.sender, request.amountBDesired);

        // Approve uniswapRouter so it can pull tokens
        request.tokenA.approveToken(address(uniswapRouter), amountAPulled);
        request.tokenB.approveToken(address(uniswapRouter), amountBPulled);

        // Update our desired amounts based on the amount pulled
        request.amountADesired = amountAPulled;
        request.amountBDesired = amountBPulled;

        (uint amountA, uint amountB, uint liquidity) = uniswapRouter.addLiquidity(
            request.tokenA,
            request.tokenB,
            request.amountADesired,
            request.amountBDesired,
            request.amountAMin,
            request.amountBMin,
            request.to,
            request.deadline
        );

        // Send leftovers
        request.tokenA.withdrawTokens(msg.sender, request.amountADesired - amountA);
        request.tokenB.withdrawTokens(msg.sender, request.amountBDesired - amountB);

        return liquidity;
    }

    /**
     * ..
     */
    receive() external payable {}
}
