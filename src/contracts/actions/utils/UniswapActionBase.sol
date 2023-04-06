// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';

/**
 * An abstract contract that provides helpers functions and logic for our UniSwap actions.
 *
 * @author Twade
 */
abstract contract UniswapActionBase is IAction, IERC721Receiver, Ownable, Pausable {

    /// Stores our Uniswap position manager
    IUniswapV3NonfungiblePositionManager public positionManager;

    /**
     * Assigns our Uniswap V3 position manager contract that will be called at
     * various points to interact with the platform.
     *
     * @param _positionManager The address of the UV3 position manager contract
     */
    function _setPositionManager(address _positionManager) internal {
        positionManager = IUniswapV3NonfungiblePositionManager(_positionManager);
    }

    /**
     * Pauses execution functionality.
     *
     * @param _p Boolean value for if the vault should be paused
     */
    function pause(bool _p) external onlyOwner {
        if (_p) _pause();
        else _unpause();
    }

    /**
     * Implementing `onERC721Received` so this contract can receive custody of erc721 tokens.
     *
     * @dev Note that the operator is recorded as the owner of the deposited NFT.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external view override returns (bytes4) {
        // Ensure that the sender of the ERC721 is the Uniswap position manager
        require(msg.sender == address(positionManager), 'Not a Uniswap NFT');

        return this.onERC721Received.selector;
    }

    /**
     * ..
     */
    modifier requiresUniswapToken(uint tokenId) {
        // Call to safeTransfer will trigger `onERC721Received` which must return
        // the selector else transfer will fail.
        positionManager.safeTransferFrom(msg.sender, address(this), tokenId);

        // Action our function logic that requires possession of the UV3 token
        _;

        // Return the token back to the original owner
        positionManager.safeTransferFrom(address(this), msg.sender, tokenId);
    }

}
