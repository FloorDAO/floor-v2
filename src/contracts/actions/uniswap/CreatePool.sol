// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
 * already present with the fee amount specified.
 *
 * @author Twade
 */
contract UniswapCreatePool is IAction, Ownable, Pausable {

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

    /// ..
    IUniswapV3NonfungiblePositionManager public immutable positionManager;

    /**
     * ..
     */
    constructor(address _positionManager) {
        positionManager = IUniswapV3NonfungiblePositionManager(_positionManager);
    }

    /**
     * Creates a Uniswap liquidity pool for 2 tokens if there is not currently a pool
     * already present with the fee amount specified. If the pool does already exist,
     * then the existing pool address will be returned in the call anyway.
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // If our token attributes are misaligned then we need to switch them around
        // as this will raise a revert later on in the transaction.
        if (request.token0 > request.token1) {
            (request.token0, request.token1) = (request.token1, request.token0);
        }

        // Create our Uniswap pool if it does not already exist
        positionManager.createAndInitializePoolIfNecessary(
            request.token0,
            request.token1,
            request.fee,
            request.sqrtPriceX96
        );

        // Empty return value, as we will need to pull the newly created pool address
        // from the transaction.
        return 0;
    }
}
