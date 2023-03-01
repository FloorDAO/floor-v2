// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

/**
 * ..
 *
 * @author Twade
 */
contract UniswapAddLiquidity is IAction, Ownable, Pausable {
    using TokenUtils for address;

    /// @param tokenId - The ID of the token for which liquidity is being increased
    /// @param amount0Desired - The desired amount of token0 that should be supplied,
    /// @param amount1Desired - The desired amount of token1 that should be supplied,
    /// @param amount0Min - The minimum amount of token0 that should be supplied,
    /// @param amount1Min - The minimum amount of token1 that should be supplied,
    /// @param deadline - The time by which the transaction must be included to effect the change
    /// @param from - account to take amounts from
    /// @param token0 - address of the first token
    /// @param token1 - address of the second token
    struct ActionRequest {
        uint tokenId;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
        address from;
        address token0;
        address token1;
    }

    /// ..
    IUniswapV3NonfungiblePositionManager positionManager;

    /**
     * ..
     */
    constructor(address _positionManager) {
        positionManager = IUniswapV3NonfungiblePositionManager(_positionManager);
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Fetch tokens from address
        uint amount0Pulled = request.token0.pullTokensIfNeeded(request.from, request.amount0Desired);
        uint amount1Pulled = request.token1.pullTokensIfNeeded(request.from, request.amount1Desired);

        // Approve positionManager so it can pull tokens
        request.token0.approveToken(address(positionManager), amount0Pulled);
        request.token1.approveToken(address(positionManager), amount1Pulled);

        request.amount0Desired = amount0Pulled;
        request.amount1Desired = amount1Pulled;

        // Increase our liquidity position
        (uint liquidity, uint amount0, uint amount1) = positionManager.increaseLiquidity(
            IUniswapV3NonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: request.tokenId,
                amount0Desired: request.amount0Desired,
                amount1Desired: request.amount1Desired,
                amount0Min: request.amount0Min,
                amount1Min: request.amount1Min,
                deadline: request.deadline
            })
        );

        // send leftovers
        request.token0.withdrawTokens(request.from, request.amount0Desired - amount0);
        request.token1.withdrawTokens(request.from, request.amount1Desired - amount1);

        return uint(liquidity);
    }
}
