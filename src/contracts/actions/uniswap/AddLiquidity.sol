// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';
import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * Adds liquidity against an existing Uniswap ERC721 position.
 *
 * @author Twade
 */
contract UniswapAddLiquidity is UniswapActionBase {
    using TokenUtils for address;

    /// @param tokenId - The ID of the token for which liquidity is being increased
    /// @param token0 - address of the first token
    /// @param token1 - address of the second token
    /// @param amount0Desired - The desired amount of token0 that should be supplied,
    /// @param amount1Desired - The desired amount of token1 that should be supplied,
    /// @param amount0Min - The minimum amount of token0 that should be supplied,
    /// @param amount1Min - The minimum amount of token1 that should be supplied,
    /// @param deadline - The time by which the transaction must be included to effect the change
    struct ActionRequest {
        // @dev If the tokenId is set to 0, then a new token will be minted
        uint tokenId;
        address token0;
        address token1;
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        uint deadline;
    }

    /**
     * Assigns our Uniswap V3 position manager contract that will be called at
     * various points to interact with the platform.
     *
     * @param _positionManager The address of the UV3 position manager contract
     */
    constructor(address _positionManager) {
        _setPositionManager(_positionManager);
    }

    /**
     * Adds liquidity to an existing ERC721 position.
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct and call our internal execute logic
        return _execute(abi.decode(_request, (ActionRequest)));
    }

    function _execute(ActionRequest memory request) internal requiresUniswapToken(request.tokenId) returns (uint) {
        // Fetch tokens from address
        uint amount0Pulled = request.token0.pullTokensIfNeeded(msg.sender, request.amount0Desired);
        uint amount1Pulled = request.token1.pullTokensIfNeeded(msg.sender, request.amount1Desired);

        // Approve positionManager so it can pull tokens
        request.token0.approveToken(address(positionManager), amount0Pulled);
        request.token1.approveToken(address(positionManager), amount1Pulled);

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

        // Send leftovers back to the caller
        request.token0.withdrawTokens(msg.sender, request.amount0Desired - amount0);
        request.token1.withdrawTokens(msg.sender, request.amount1Desired - amount1);

        // Remove approvals
        request.token0.approveToken(address(positionManager), 0);
        request.token1.approveToken(address(positionManager), 0);

        return uint(liquidity);
    }
}
