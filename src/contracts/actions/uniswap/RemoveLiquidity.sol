// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '../../../interfaces/actions/Action.sol';
import {IUniswapV3NonfungiblePositionManager} from "../../../interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol";

import {TokenUtils} from "../../utils/TokenUtils.sol";


/// @title Decreases liquidity from a position represented by tokenID, and collects tokensOwed from position to recipient
contract UniswapRemoveLiquidity is IAction, Ownable, Pausable {

    using TokenUtils for address;

    /// @param tokenId - The ID of the token for which liquidity is being decreased
    /// @param liquidity -The amount by which liquidity will be decreased,
    /// @param amount0Min - The minimum amount of token0 that should be accounted for the burned liquidity,
    /// @param amount1Min - The minimum amount of token1 that should be accounted for the burned liquidity,
    /// @param deadline - The time by which the transaction must be included to effect the change
    /// @param recipient - accounts to receive the tokens
    /// @param amount0Max - The maximum amount of token0 to collect
    /// @param amount1Max - The maximum amount of token1 to collect
    struct ActionRequest{
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// ..
    IUniswapV3NonfungiblePositionManager positionManager;

    /**
     * ..
     */
    constructor (address _positionManager) {
        positionManager = IUniswapV3NonfungiblePositionManager(_positionManager);
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Burns liquidity stated, amount0Min and amount1Min are the least you get for
        // burning that liquidity (else reverted).
        positionManager.decreaseLiquidity(
            IUniswapV3NonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: request.tokenId,
                liquidity: request.liquidity,
                amount0Min: request.amount0Min,
                amount1Min: request.amount1Min,
                deadline: request.deadline
            })
        );

        // Collects from tokensOwed on position, sends to recipient, up to amountMax
        (uint amount0,) = positionManager.collect(
            IUniswapV3NonfungiblePositionManager.CollectParams({
                tokenId: request.tokenId,
                recipient: request.recipient,
                amount0Max: request.amount0Max,
                amount1Max: request.amount1Max
            })
        );

        return amount0;
    }

}
