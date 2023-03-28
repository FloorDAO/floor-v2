// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {INFTXUnstakingInventoryZap} from '@floor-interfaces/nftx/NFTXUnstakingInventoryZap.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {INftStakingStrategy} from '@floor-interfaces/staking/NftStakingStrategy.sol';

/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting through the calculation of a multiplier.
 */

contract NftStakingNFTXV2 is INftStakingStrategy, Ownable {

    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;
    mapping(address => address) public underlyingXTokenMapping;

    /// Store a mapping of NFTX vault address to vault ID for gas savings
    mapping(address => uint) internal cachedNftxVaultId;

    /// Store our NFTX staking zaps
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /// Temp. user store for ERC721 receipt
    address private _nftReceiver;

    // Allows NFTX references for when receiving rewards
    address internal inventoryStaking;
    address internal treasury;
    address internal nftStaking;

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
            // Approve the staking zap to handle the collection tokens
            if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId[i], bytes(''));
                IERC721(_collection).approve(address(stakingZap), _tokenId[i]);
            } else {
                // Confirm that the PUNK belongs to the caller
                bytes memory punkIndexToAddress = abi.encodeWithSignature('punkIndexToAddress(uint256)', _tokenId[i]);
                (bool success, bytes memory result) = address(_collection).staticcall(punkIndexToAddress);
                require(success && abi.decode(result, (address)) == msg.sender, 'Not the NFT owner');

                // Buy our PUNK for zero value
                bytes memory data = abi.encodeWithSignature('buyPunk(uint256)', _tokenId[i]);
                (success, result) = address(_collection).call(data);
                require(success, string(result));

                // Approve the staking zap to buy for zero value
                data = abi.encodeWithSignature('offerPunkForSaleToAddress(uint256,uint256,address)', _tokenId[i], 0, address(stakingZap));
                (success, result) = address(_collection).call(data);
                require(success, string(result));
            }

            unchecked { ++i; }
        }

        // Stake the token into NFTX vault
        stakingZap.provideInventory721(_getVaultId(_collection), _tokenId);
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param recipient The recipient of the unstaked NFT
     * @param _collection The collection to unstake
     * @param _collection The number of NFTs to unstake
     * @param _collection The dust of NFT to unstake
     */
    function unstake(address recipient, address _collection, uint numNfts, uint remainingPortionToUnstake) external onlyNftStaking {
        // Set our NFT receiver so that our callback function can hook into the correct
        // recipient. We have to do this as NFTX doesn't allow a recipient to be specified
        // when calling the unstaking zap. This only needs to be done if we expect to
        // receive an NFT.
        if (numNfts != 0) {
            _nftReceiver = recipient;
        }

        // Unstake all inventory for the user for the collection. This forked version of the
        // NFTX unstaking zap allows us to specify the recipient, so we don't need to handle
        // any additional transfers.
        unstakingZap.unstakeInventory(_getVaultId(_collection), numNfts, remainingPortionToUnstake);

        // After our NFTs have been unstaked, we want to make sure we delete the receiver
        delete _nftReceiver;
    }

    /**
     * Allows rewards to be claimed from the staked NFT inventory positions.
     */
    function claimRewards(address _collection) external {
        // Get the corresponding vault ID of the collection
        uint vaultId = _getVaultId(_collection);

        // Get the amount of rewards avaialble to claim
        uint rewardsAvailable = INFTXInventoryStaking(inventoryStaking).balanceOf(vaultId, address(this));

        // If we have rewards available, then we want to claim them from the vault and transfer it
        // into our {Treasury}.
        if (rewardsAvailable != 0) {
            INFTXInventoryStaking(inventoryStaking).receiveRewards(vaultId, rewardsAvailable);
            IERC20(underlyingTokenMapping[_collection]).transfer(treasury, rewardsAvailable);
        }
    }

    /**
     * ..
     */
    function underlyingToken(address _collection) external view returns (address) {
        require(underlyingTokenMapping[_collection] != address(0), 'Unmapped collection');
        return underlyingTokenMapping[_collection];
    }

    /**
     * Sets the NFTX staking zaps that we will be interacting with.
     *
     * @param _stakingZap The {NFTXStakingZap} contract address
     * @param _unstakingZap The {NFTXUnstakingInventoryZap} contract address
     */
    function setStakingZaps(address _stakingZap, address _unstakingZap) external onlyOwner {
        require(_stakingZap != address(0));
        require(_unstakingZap != address(0));

        stakingZap = INFTXStakingZap(_stakingZap);
        unstakingZap = INFTXUnstakingInventoryZap(_unstakingZap);
    }

    /**
     * Allows us to set internal contracts that are used when claiming rewards.
     */
    function setContracts(address _inventoryStaking, address _treasury) external onlyOwner {
        inventoryStaking = _inventoryStaking;
        treasury = _treasury;
    }

    /**
     * Maps a collection address to an underlying NFTX token address. This will allow us to assign
     * a corresponding NFTX vault against our collection.
     *
     * @param _collection Our approved collection address
     * @param _token The underlying token (the NFTX vault contract address)
     */
    function setUnderlyingToken(address _collection, address _token, address _xToken) external onlyOwner {
        require(_collection != address(0));
        require(_token != address(0));

        // Map our collection to the underlying token
        underlyingTokenMapping[_collection] = _token;
        underlyingXTokenMapping[_collection] = _xToken;
    }

    /**
     * Calculates the NFTX vault ID of a collection address and then stores it to a local cache
     * as this value will not change.
     *
     * @param _collection The address of the collection being checked
     *
     * @return Numeric NFTX vault ID
     */
    function _getVaultId(address _collection) internal returns (uint) {
        // As we need to check a 0 value in our mapping to determine if it is not set, I have
        // hardcoded the vault collection that actually has a 0 ID to prevent any false positives.
        if (_collection == 0x269616D549D7e8Eaa82DFb17028d0B212D11232A) {
            return 0;
        }

        // If we have a cached mapping, then we can just return this directly
        if (cachedNftxVaultId[_collection] != 0) {
            return cachedNftxVaultId[_collection];
        }

        // Using the NFTX vault interface, reference the ERC20 which is also the vault address
        // to get the vault ID.
        return cachedNftxVaultId[_collection] = INFTXVault(underlyingTokenMapping[_collection]).vaultId();
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint tokenId, bytes memory) public virtual returns (bytes4) {
        if (_nftReceiver != address(0)) {
            IERC721(msg.sender).safeTransferFrom(address(this), _nftReceiver, tokenId);
        }
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
