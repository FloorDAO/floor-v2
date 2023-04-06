// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';
import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * ..
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
     * ..
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

        // {"token0":"0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48","token1":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2","fee":"500","tickLower":"-887272","tickUpper":"887272","amount0Desired":"10000000","amount1Desired":"5000000000000000","amount0Min":"0","amount1Min":"0","recipient":"0x0f294726A2E3817529254F81e0C195b6cd0C834f","deadline":"1680777083"}

        // Create our ERC721 and fund it with an initial desired amount of each token
        (uint tokenId, , uint amount0, uint amount1) = positionManager.mint(
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
