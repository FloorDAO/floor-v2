// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {INFTXUnstakingInventoryZap} from '@floor-interfaces/forks/NFTXUnstakingInventoryZap.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';


/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting.
 */

contract NFTStaking is Ownable, Pausable {

    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;

    /// Stores the epoch start time of staking, and the duration of the staking
    mapping(bytes32 => uint) public stakingEpochStart;
    mapping(bytes32 => uint) public stakingEpochCount;

    /// Stores the boosted number of votes available to a user
    mapping(bytes32 => uint) public userTokensStaked;

    /// Stores the boosted number of votes available to a user for each collection
    mapping(bytes32 => uint) internal _userBoost;

    // Stores an array of collections the user has currently staked NFTs for
    mapping(address => address[]) public userCollections;
    mapping(bytes32 => uint) public userCollectionIndex;

    // Store a mapping of NFTX vault address to vault ID for gas savings
    mapping(address => uint) internal cachedNftxVaultId;

    /// Store the amount of discount applied to voting power of staked NFT
    uint public voteDiscount;

    // Store the current epoch, which will be updated by our internal calls to sync
    uint public currentEpoch;

    // Store our pricing executor that will determine the vote power of our NFT
    IBasePricingExecutor public pricingExecutor;

    // Store our NFTX staking zaps
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /**
     * Sets up our immutable contract addresses.
     */
    constructor(address _pricingExecutor, uint _voteDiscount) {
        require(_pricingExecutor != address(0), 'Address not zero');
        require(_voteDiscount < 10000, 'Must be less that 10000');

        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        voteDiscount = _voteDiscount;
    }

    /**
     * Gets the total boost value for the user, based on the amount of NFTs that they have
     * staked, as well as the value and duration at which they staked at.
     *
     * @param _account The address of the user we are checking the boost value of
     *
     * @return boost_ The boost value for the user
     */
    function userBoost(address _account) external view returns (uint boost_) {
        // Loop over each user's collections
        for (uint i; i < userCollections[_account].length;) {
            // Increment our boost value against the amount of boost in each collection
            boost_ += _userBoost[keccak256(abi.encode(_account, userCollections[_account][i]))];
            unchecked { ++i; }
        }

        return (boost_ / 10000) * voteDiscount;
    }

    /**
     * Gets the total boost value for the user, for a specific collection, based on the
     * amount of NFTs that they have staked, as well as the value and duration at which
     * they staked at.
     *
     * @param _account The address of the user we are checking the boost value of
     * @param _collection The collection we are finding the boost value of
     *
     * @return boost_ The boost value for the user, for the collection
     */
    function userBoost(address _account, address _collection) external view returns (uint) {
        return (_userBoost[keccak256(abi.encode(_account, _collection))] / 10000) * voteDiscount;
    }

    /**
     * Stakes an approved collection NFT into the contract and provides a boost based on
     * the price of the underlying ERC20.
     *
     * @dev This can only be called when the contract is not paused.
     *
     * @param _collection Approved collection contract
     * @param _tokenId[] Token ID to be staked
     * @param _epochCount The number of epochs to stake for
     */
    function stake(address _collection, uint[] calldata _tokenId, uint _epochCount) external whenNotPaused {
        // Validate the number of epochs staked
        // ..

        // Ensure we have a mapped underlying token
        require(underlyingTokenMapping[_collection] != address(0), 'Underlying token not found');

        // Convert our user and collection to a bytes32 reference, creating a smaller 1d mapping,
        // as opposed to an otherwise 2d address mapping.
        bytes32 userCollectionHash = keccak256(abi.encode(msg.sender, _collection));

        // Track the number of tokens stored by the sender
        unchecked { userTokensStaked[userCollectionHash] += 1; }

        // Get the number of tokens we will be transferring
        uint tokensLength = _tokenId.length;

        // Transfer the token into the contract
        for (uint i; i < tokensLength;) {
            IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId[i], bytes(''));
            unchecked { ++i; }
        }

        // Find the current value of the token
        uint tokenValue = pricingExecutor.getFloorPrice(underlyingTokenMapping[_collection]);
        require(tokenValue != 0, 'Unknown token price');

        // If we don't currently have any tokens stored for the collection, then we need to push
        // the collection address onto our list of user's collections.
        if (userTokensStaked[userCollectionHash] == 0) {
            userCollectionIndex[userCollectionHash] = userCollections[msg.sender].length;
            userCollections[msg.sender].push(_collection);
        }

        // Update the number of tokens that our user has staked
        userTokensStaked[userCollectionHash] += tokensLength;

        // Grant the user a vote boost based on the value of the token. We replace their existing
        // boosted value with an equivalent of a restaked value based on the new token value and
        // the new total number of staked NFTs.
        unchecked {
            _userBoost[userCollectionHash] = tokenValue * userTokensStaked[userCollectionHash];
        }

        // Stake the token into NFTX vault
        stakingZap.provideInventory721(_getVaultId(_collection), _tokenId);

        // Store the epoch starting epoch and the duration it is being staked for
        stakingEpochStart[userCollectionHash] = currentEpoch;
        stakingEpochCount[userCollectionHash] = _epochCount;

        // Fire an event to show staked tokens
        // emit TokensStaked(msg.sender, _tokenId, tokenValue, currentEpoch, epochCount);
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param _collection The collection to unstake
     */
    function unstake(address _collection) external {
        // Get our user collection hash
        bytes32 userCollectionHash = keccak256(abi.encode(msg.sender, _collection));

        // Determine the number of full NFTs that we can receive when unstaking, as well as any
        // dust remaining afterwards. These amounts will vary depending on the remaining period
        // when unstaking.
        uint numNfts;
        uint remainingPortionToUnstake;

        // To do this, we build up our `remainingPortionToUnstake` variable to account for all of
        // our returned value. We can then divide this by `1 ether` to find the number of whole
        // tokens that can be withdrawn. This will leave the `remainingPortionToUnstake` with just
        // the dust allocation.
        remainingPortionToUnstake = ((userTokensStaked[userCollectionHash] * 1 ether) * 104) / (stakingEpochCount[userCollectionHash] / (currentEpoch - stakingEpochStart[userCollectionHash]));
        while (remainingPortionToUnstake > 1 ether) {
            unchecked {
                remainingPortionToUnstake -= 1 ether;
                numNfts += 1;
            }
        }

        // Unstake all inventory for the user for the collection. This forked version of the
        // NFTX unstaking zap allows us to specify the recipient, so we don't need to handle
        // any additional transfers.
        unstakingZap.unstakeInventory(_getVaultId(_collection), numNfts, remainingPortionToUnstake, msg.sender);

        // Remove our number of staked tokens for the collection
        userTokensStaked[userCollectionHash] = 0;

        // Delete the collection from our user's collection array
        delete userCollections[msg.sender][userCollectionIndex[userCollectionHash]];

        // Delete epoch information for the user collection hash
        delete stakingEpochStart[userCollectionHash];
        delete stakingEpochCount[userCollectionHash];

        // Fire an event to show unstaked tokens
        // emit TokensUnStaked(msg.sender, _tokenId, tokenValue);
    }

    /**
     * ..
     */
    function setVoteDiscount(uint _voteDiscount) external onlyOwner {
        require(_voteDiscount < 10000, 'Must be less that 10000');
        voteDiscount = _voteDiscount;
    }

    /**
     * ..
     */
    function setPricingExecutor(address _pricingExecutor) external onlyOwner {
        require(_pricingExecutor != address(0), 'Address not zero');
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
    }

    /**
     * ..
     */
    function setStakingZaps(address _stakingZap, address _unstakingZap) external onlyOwner {
        stakingZap = INFTXStakingZap(_stakingZap);
        unstakingZap = INFTXUnstakingInventoryZap(_unstakingZap);
    }

    /**
     * ..
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
     * ..
     */
    function claimRewards(address _collection) external {
        // Get the corresponding vault ID of the collection
        uint vaultId = _getVaultId(_collection);

        // TODO: Allow the actual NFTX inventory staking contract to be referenced
        address inventoryStaking = address(this);
        address treasury = address(this);

        // Get the amount of rewards avaialble to claim
        uint rewardsAvailable = INFTXInventoryStaking(inventoryStaking).balanceOf(vaultId, address(this));

        // If we have rewards available, then we want to claim them from the vault and transfer it
        // into our {Treasury}.
        if (rewardsAvailable != 0) {
            INFTXInventoryStaking(inventoryStaking).receiveRewards(vaultId, rewardsAvailable);
            IERC20(underlyingTokenMapping[_collection]).transfer(treasury, rewardsAvailable);
        }
    }

}
