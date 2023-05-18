// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';
import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * Mints a position against a Uniswap pool, minting an ERC721 that will be
 * passed to the sender. This ERC721 will referenced by subsequent Uniswap
 * actions to allow liquidity management and reward collection.
 *
 * @author Twade
 */
contract UniswapMintPosition is UniswapActionBase {
    using TokenUtils for address;

    struct ActionRequest {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
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
     * Mints an ERC721 position against a pool and provides initial liquidity.
     */
    function execute(bytes calldata _request) public payable whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct and call our internal execute logic
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Fetch tokens from address
        uint amount0Pulled = request.token0.pullTokensIfNeeded(msg.sender, request.amount0Desired);
        uint amount1Pulled = request.token1.pullTokensIfNeeded(msg.sender, request.amount1Desired);

        // Approve positionManager so it can pull tokens
        request.token0.approveToken(address(positionManager), request.amount0Desired);
        request.token1.approveToken(address(positionManager), request.amount1Desired);

        // Create our ERC721 and fund it with an initial desired amount of each token
        (uint tokenId,, uint amount0, uint amount1) = positionManager.mint(
            IUniswapV3NonfungiblePositionManager.MintParams({
                token0: request.token0,
                token1: request.token1,
                fee: request.fee,
                tickLower: request.tickLower,
                tickUpper: request.tickUpper,
                amount0Desired: request.amount0Desired,
                amount1Desired: request.amount1Desired,
                amount0Min: request.amount0Min,
                amount1Min: request.amount1Min,
                recipient: msg.sender,
                deadline: request.deadline
            })
        );

        // Send leftovers back to the caller
        request.token0.withdrawTokens(msg.sender, amount0Pulled - amount0);
        request.token1.withdrawTokens(msg.sender, amount1Pulled - amount1);

        // Remove approvals
        request.token0.approveToken(address(positionManager), 0);
        request.token1.approveToken(address(positionManager), 0);

        return tokenId;
    }
}
