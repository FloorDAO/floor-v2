// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapActionBase} from '@floor/actions/utils/UniswapActionBase.sol';

/**
 * Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
 * already present with the fee amount specified.
 *
 * @author Twade
 */
contract UniswapCreatePool is UniswapActionBase {
    /// @param token0 Address of the first token
    /// @param token1 Address of the second token
    /// @param fee Fee for the pool
    /// @param sqrtPriceX96 Uniswap magic
    struct ActionRequest {
        address token0;
        address token1;
        uint24 fee;
        uint160 sqrtPriceX96;
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
     * Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
     * already present with the fee amount specified. If the pool does already exist,
     * then the existing pool address will be returned in the call anyway.
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // If our token attributes are misaligned then we need to switch them around
        // as this will raise a revert later on in the transaction.
        if (request.token0 > request.token1) {
            (request.token0, request.token1) = (request.token1, request.token0);
        }

        // Create our Uniswap pool if it does not already exist
        address pool = positionManager.createAndInitializePoolIfNecessary(request.token0, request.token1, request.fee, request.sqrtPriceX96);

        // Emit our `ActionEvent`
        emit ActionEvent('UniswapCreatePool', _request);

        // We cast the pool address to an integer so that it can be returned
        return uint(uint160(pool));
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }
}
