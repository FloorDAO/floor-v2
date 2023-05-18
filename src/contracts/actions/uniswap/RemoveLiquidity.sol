// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * Decreases liquidity from a position represented by tokenID.
 */
contract UniswapRemoveLiquidity is UniswapActionBase {
    /// @param tokenId - The ID of the token for which liquidity is being decreased
    /// @param liquidity -The amount by which liquidity will be decreased,
    /// @param amount0Min - The minimum amount of token0 that should be accounted for the burned liquidity,
    /// @param amount1Min - The minimum amount of token1 that should be accounted for the burned liquidity,
    /// @param deadline - The time by which the transaction must be included to effect the change
    struct ActionRequest {
        uint tokenId;
        uint128 liquidity;
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
     * Removes liquidity from an existing ERC721 position.
     *
     * @dev To collect the liquidity generated, we will need to subsequently call `collect`
     * on the pool using the {UniswapClaimPoolRewards} action.
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));
        return _execute(request);
    }

    function _execute(ActionRequest memory request) internal requiresUniswapToken(request.tokenId) returns (uint) {
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

        return 0;
    }
}
