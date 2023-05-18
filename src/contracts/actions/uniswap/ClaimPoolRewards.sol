// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
 * already present with the fee amount specified.
 *
 * @author Twade
 */
contract UniswapClaimPoolRewards is UniswapActionBase {
    /// @param tokenId The id of the erc721 token
    /// @return amount0 The max amount of fees collected in token0
    /// @return amount1 The max amount of fees collected in token1
    struct ActionRequest {
        uint tokenId;
        uint128 amount0;
        uint128 amount1;
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
     * Collects the fees associated with provided liquidity.
     *
     * @dev The contract must hold the erc721 token before it can collect fees.
     */
    function execute(bytes calldata _request) public payable whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));
        return _execute(request);
    }

    function _execute(ActionRequest memory request) internal requiresUniswapToken(request.tokenId) returns (uint) {
        // Collect fees from the pool
        positionManager.collect(
            IUniswapV3NonfungiblePositionManager.CollectParams({
                tokenId: request.tokenId,
                recipient: msg.sender,
                amount0Max: request.amount0,
                amount1Max: request.amount1
            })
        );

        // Empty return value, as we have 2 forms of fees returned
        return 0;
    }
}
