// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

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

    /// ..
    address internal immutable nftStaking;

    /// Map collection => user => boolean
    mapping (address => mapping (address => uint[])) public tokenIds;
    mapping (address => mapping (address => uint[])) public tokenAmounts;

    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;

    /**
     * Sets up our immutable contract addresses.
     */
    constructor(address _nftStaking) {
        nftStaking = _nftStaking;
    }

    /**
     * Shows the address that should be approved by a staking user.
     */
    function approvalAddress() external view returns (address) {
        return address(this);
    }

    /**
     * Stakes an approved collection NFT into the contract and provides a boost based on
     * the price of the underlying ERC20.
     *
     * @dev This can only be called when the contract is not paused.
     *
     * @param _user Address of the user staking their tokens
     * @param _collection Approved collection contract
     * @param _tokenId[] Token IDs to be staked
     * @param _amount[] The number of tokens to transfer
     * @param _is1155 If the collection is an ERC1155 standard
     */
    function stake(
        address _user,
        address _collection,
        uint[] calldata _tokenId,
        uint[] calldata _amount,
        bool _is1155
    ) external onlyNftStaking {
        // If we have an 1155 collection, then we can use batch transfer
        if (_is1155) {
            IERC1155(_collection).safeBatchTransferFrom(_user, address(this), _tokenId, _amount, '');
        }

        uint length = _tokenId.length;
        for (uint i; i < length;) {
            // Match the user as holding the collection token in our locker
            tokenIds[_collection][_user].push(_tokenId[i]);
            tokenAmounts[_collection][_user].push(_amount[i]);

            // If we have a 721 token, then we need to iterate over our tokens to transfer
            // and approve them individually.
            if (!_is1155) {
                // Approve the staking zap to handle the collection tokens
                if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                    IERC721(_collection).safeTransferFrom(_user, address(this), _tokenId[i], '');
                } else {
                    // Confirm that the PUNK belongs to the caller
                    bytes memory punkIndexToAddress = abi.encodeWithSignature('punkIndexToAddress(uint256)', _tokenId[i]);
                    (bool success, bytes memory result) = address(_collection).staticcall(punkIndexToAddress);
                    require(success && abi.decode(result, (address)) == _user, 'Not the NFT owner');

                    // Buy our PUNK for zero value
                    bytes memory data = abi.encodeWithSignature('buyPunk(uint256)', _tokenId[i]);
                    (success, result) = address(_collection).call(data);
                    require(success, string(result));
                }
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
     * @param _is1155 If the collection matches the EIP-1155 standard
     */
    function unstake(
        address recipient,
        address _collection,
        uint numNfts,
        uint /* baseNfts */,
        uint remainingPortionToUnstake,
        bool _is1155
    ) external onlyNftStaking {
        // Our locker does not allow for portion unstaking
        require(remainingPortionToUnstake == 0, 'Cannot unstake portion');

        // Get a list of staked token IDs
        uint[] memory _tokenIds = tokenIds[_collection][recipient];
        uint[] memory _tokenAmounts = tokenAmounts[_collection][recipient];

        // Confirm that our user has sufficient tokens to unstake
        uint totalStaked;
        uint length = _tokenIds.length;
        for (uint i; i < length;) {
            unchecked {
                totalStaked += _tokenAmounts[i];
                ++i;
            }
        }

        require(numNfts == totalStaked, 'Cannot unstake portion');

        // If we have an 1155 collection, then we can use batch transfer
        if (_is1155) {
            IERC1155(_collection).safeBatchTransferFrom(address(this), recipient, _tokenIds, _tokenAmounts, '');
        } else {
            // Unstake all inventory for the user for the collection
            for (uint i; i < length;) {
                if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                    IERC721(_collection).safeTransferFrom(address(this), recipient, _tokenIds[i], bytes(''));
                } else {
                    // Approve the recipient to buy for zero value
                    bytes memory data = abi.encodeWithSignature('offerPunkForSaleToAddress(uint256,uint256,address)', _tokenIds[i], 0, recipient);
                    (bool success, bytes memory result) = address(_collection).call(data);
                    require(success, string(result));
                }

                unchecked { ++i; }
            }
        }

        // Remove all tokens from the user's stake
        delete tokenIds[_collection][recipient];
        delete tokenAmounts[_collection][recipient];
    }

    /**
     * We don't have any rewards as we only deposit and withdraw a 1:1 mapping
     * of tokens and their amounts. No rewards are generated.
     */
    function rewardsAvailable(address /* _collection */) external pure returns (uint) {
        return 0;
    }

    /**
     * We don't have any rewards as we only deposit and withdraw a 1:1 mapping
     * of tokens and their amounts. No rewards are generated.
     */
    function claimRewards(address /* _collection */) external pure returns (uint) {
        return 0;
    }

    /**
     * Gets the underlying token for a collection.
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
     * Allows the contract to receive ERC1155 tokens.
     */
    function onERC1155Received(address, address, uint, uint, bytes calldata) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * Allows the contract to receive batch ERC1155 tokens.
     */
    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * Ensures that only the {NftStaking} contract can call the function.
     */
    modifier onlyNftStaking {
        require(msg.sender == nftStaking, 'Invalid caller');
        _;
    }
}
