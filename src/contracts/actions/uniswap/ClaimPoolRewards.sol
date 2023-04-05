// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

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

    /// @param tokenId The id of the erc721 token
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    struct ActionRequest {
        uint tokenId;
        uint128 amount0;
        uint128 amount1;
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
     * Collects the fees associated with provided liquidity.
     *
     * @dev The contract must hold the erc721 token before it can collect fees.
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Call to safeTransfer will trigger `onERC721Received` which must return the selector else transfer will fail
        positionManager.safeTransferFrom(msg.sender, address(this), request.tokenId);

        positionManager.collect(
            IUniswapV3NonfungiblePositionManager.CollectParams({
                tokenId: request.tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Return the token back to the treasury
        positionManager.safeTransferFrom(address(this), msg.sender, request.tokenId);

        // Empty return value, as we will need to pull the newly created pool address
        // from the transaction.
        return 0;
    }

    function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
