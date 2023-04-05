// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {INftStakingStrategy} from '@floor-interfaces/staking/NftStakingStrategy.sol';

/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting through the calculation of a multiplier.
 *
 * Unlike other staking strategies, this simply locks them without external
 * interaction. This means that it generates no yield or benefit other that vote
 * locking.
 */

contract NftStakingLocker is INftStakingStrategy, Ownable {

    address internal nftStaking;

    /// Map collection => user => boolean
    mapping (address => mapping (address => bool)) public tokensLocked;
    mapping (address => mapping (address => uint[])) public tokenIds;

    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;

    /**
     * Sets up our immutable contract addresses.
     */
    constructor(address _nftStaking) {
        nftStaking = _nftStaking;
    }

    /**
     * Stakes an approved collection NFT into the contract and provides a boost based on
     * the price of the underlying ERC20.
     *
     * @dev This can only be called when the contract is not paused.
     *
     * @param _collection Approved collection contract
     * @param _tokenId[] Token IDs to be staked
     */
    function stake(address _collection, uint[] calldata _tokenId) external onlyNftStaking {
        uint length = _tokenId.length;
        for (uint i; i < length;) {
            // Match the user as holding the collection token in our locker
            tokensLocked[_collection][msg.sender] = true;
            tokenIds[_collection][msg.sender].push(_tokenId[i]);

            // Approve the staking zap to handle the collection tokens
            if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId[i], bytes(''));
            } else {
                // Confirm that the PUNK belongs to the caller
                bytes memory punkIndexToAddress = abi.encodeWithSignature('punkIndexToAddress(uint256)', _tokenId[i]);
                (bool success, bytes memory result) = address(_collection).staticcall(punkIndexToAddress);
                require(success && abi.decode(result, (address)) == msg.sender, 'Not the NFT owner');

                // Buy our PUNK for zero value
                bytes memory data = abi.encodeWithSignature('buyPunk(uint256)', _tokenId[i]);
                (success, result) = address(_collection).call(data);
                require(success, string(result));
            }

            unchecked { ++i; }
        }
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param recipient The recipient of the unstaked NFT
     * @param _collection The collection to unstake
     * @param numNfts The number of NFTs to unstake
     * @param remainingPortionToUnstake The dust of NFT to unstake
     */
    function unstake(address recipient, address _collection, uint numNfts, uint remainingPortionToUnstake) external onlyNftStaking {
        // Our locker does not allow for portion unstaking
        require(remainingPortionToUnstake == 0, 'Cannot unstake portion');

        // Confirm that our user has the rights to unstake
        require(tokensLocked[_collection][msg.sender], 'Token not locked');

        // Get a list of staked token IDs
        uint[] memory _tokenIds = tokenIds[_collection][msg.sender];

        // Remove all tokens from the user's stake
        delete tokenIds[_collection][msg.sender];

        // Unstake all inventory for the user for the collection
        uint length = _tokenIds.length;
        require(numNfts == length, 'Cannot unstake portion');

        for (uint i; i < length;) {
            if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                IERC721(_collection).safeTransferFrom(address(this), recipient, _tokenIds[i], bytes(''));
            } else {
                // Approve the recipient to buy for zero value
                bytes memory data = abi.encodeWithSignature('offerPunkForSaleToAddress(uint256,uint256,address)', _tokenIds[i], 0, recipient);
                (bool success, bytes memory result) = address(_collection).call(data);
                require(success, string(result));
            }

            // Unlock the token
            tokensLocked[_collection][msg.sender] = false;

            unchecked { ++i; }
        }
    }

    /**
     * Allows rewards to be claimed from the staked NFT inventory positions.
     */
    function claimRewards(address _collection) external {
        // ..
    }

    /**
     * ..
     */
    function underlyingToken(address _collection) external view returns (address) {
        require(underlyingTokenMapping[_collection] != address(0), 'Unmapped collection');
        return underlyingTokenMapping[_collection];
    }

    /**
     * Maps a collection address to an underlying NFTX token address. This will allow us to generate
     * a price calculation against the collection
     *
     * @param _collection Our approved collection address
     * @param _token The underlying token (the NFTX vault contract address)
     */
    function setUnderlyingToken(address _collection, address _token, address /* _xToken */) external onlyOwner {
        require(_collection != address(0));
        require(_token != address(0));

        underlyingTokenMapping[_collection] = _token;
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * ..
     */
    modifier onlyNftStaking {
        require(msg.sender == nftStaking, 'Invalid caller');
        _;
    }
}
