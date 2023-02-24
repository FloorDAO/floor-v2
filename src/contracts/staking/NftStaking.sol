// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {ABDKMath64x64} from '@floor/forks/ABDKMath64x64.sol';

import {INFTXUnstakingInventoryZap} from '@floor-interfaces/forks/NFTXUnstakingInventoryZap.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';


/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting.
 */

contract NftStaking is INftStaking, Ownable, Pausable {

    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;

    /// Stores the epoch start time of staking, and the duration of the staking
    mapping(bytes32 => uint) public stakingEpochStart;
    mapping(bytes32 => uint) public stakingEpochCount;

    /// Stores the boosted number of votes available to a user
    mapping(bytes32 => uint) public userTokensStaked;

    // Stores an array of collections the user has currently staked NFTs for
    mapping(address => address[]) internal collectionStakers;
    mapping(bytes32 => uint) public collectionStakerIndex;

    // Store a mapping of NFTX vault address to vault ID for gas savings
    mapping(address => uint) internal cachedNftxVaultId;

    /// Store the amount of discount applied to voting power of staked NFT
    uint public voteDiscount;
    uint public sweepModifier;

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
     * Gets the total boost value for collection, based on the amount of NFTs that have been
     * staked, as well as the value and duration at which they staked at.
     *
     * @param _collection The address of the collection we are checking the boost multiplier of
     *
     * @return boost_ The boost multiplier for the collection to 9 decimal places
     */
    function collectionBoost(address _collection) external view returns (uint boost_) {
        // Get the latest cached price of a collection. We need to get the number of FLOOR
        // tokens that this equates to, without the additional decimals.
        uint cachedFloorPrice = pricingExecutor.getLatestFloorPrice(underlyingTokenMapping[_collection]);

        // Store our some variables for use throughout the loop for gas saves
        bytes32 userCollectionHash;
        uint sweepPower;
        uint sweepTotal;
        uint stakedSweepPower;
        uint epochModifier;

        // Loop through all stakes against a collection and summise the sweep power based on
        // the number staked and remaining epoch duration.
        for (uint i; i < collectionStakers[_collection].length;) {
            userCollectionHash = keccak256(abi.encode(collectionStakers[_collection][i], _collection));

            unchecked {
                // Get the remaining power of the stake based on remaining epochs
                if (currentEpoch < stakingEpochStart[userCollectionHash] + stakingEpochCount[userCollectionHash]) {
                    // Determine our staked sweep power by calculating our epoch discount
                    stakedSweepPower = (((userTokensStaked[userCollectionHash] * cachedFloorPrice * voteDiscount) / 10000) * stakingEpochCount[userCollectionHash]) / 104;
                    epochModifier = ((currentEpoch - stakingEpochStart[userCollectionHash]) * 1e9) / stakingEpochCount[userCollectionHash];

                    // Add the staked sweep power to our collection total
                    sweepPower += stakedSweepPower - ((stakedSweepPower * epochModifier) / 1e9);

                    // Tally up our quantity total
                    sweepTotal += userTokensStaked[userCollectionHash];
                }

                ++i;
            }
        }

        // If we don't have any power, then our multiplier will just be 1
        if (sweepPower == 0) {
            return 1e9;
        }

        // Determine our logarithm base. When we only have one token, we get a zero result which
        // would lead to a zero division error. To avoid this, we ensure that we set a minimum
        // value of 1.
        uint _voteModifier = sweepModifier;
        if (sweepTotal == 1) {
            _voteModifier = (sweepModifier * 125) / 100;
            sweepTotal = 2;
        }

        // Apply our modifiers to our calculations to determine our final multiplier
        boost_ = (
            (
                (
                    ABDKMath64x64.toUInt(
                        ABDKMath64x64.ln(ABDKMath64x64.fromUInt(sweepPower)) * 1e6
                    ) * 1e9
                )
                /
                (
                    ABDKMath64x64.toUInt(
                        ABDKMath64x64.ln(ABDKMath64x64.fromUInt(sweepTotal)) * 1e6
                    )
                )
            ) * (
                (
                    ABDKMath64x64.toUInt(
                        ABDKMath64x64.sqrt(ABDKMath64x64.fromUInt(sweepTotal)) * 1e9
                    )
                ) - 1e9
            )
        ) / _voteModifier;

        if (boost_ < 1e9) {
            boost_ = 1e9;
        }
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

        // Get the number of tokens we will be transferring
        uint tokensLength = _tokenId.length;

        // Transfer the token into the contract and approve the staking zap to use them
        for (uint i; i < tokensLength;) {
            // Handle Punk specific logic
            if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId[i], bytes(''));
                IERC721(_collection).approve(address(stakingZap), _tokenId[i]);
            } else {
                // Confirm that the PUNK belongs to the caller
                bytes memory punkIndexToAddress = abi.encodeWithSignature('punkIndexToAddress(uint256)', _tokenId[i]);
                (bool success, bytes memory result) = address(_collection).staticcall(punkIndexToAddress);
                require(success && abi.decode(result, (address)) == msg.sender, "Not the NFT owner");

                // Buy our PUNK for zero value
                bytes memory data = abi.encodeWithSignature('buyPunk(uint256)', _tokenId[i]);
                (success, result) = address(_collection).call(data);
                require(success, string(result));

                // Approve the staking zap to buy for zero value
                data = abi.encodeWithSignature("offerPunkForSaleToAddress(uint256,uint256,address)", _tokenId[i], 0, address(stakingZap));
                (success, result) = address(_collection).call(data);
                require(success, string(result));
            }

            unchecked { ++i; }
        }

        // Find the current value of the token
        uint tokenValue = pricingExecutor.getFloorPrice(underlyingTokenMapping[_collection]);
        require(tokenValue != 0, 'Unknown token price');

        // If we don't currently have any tokens stored for the collection, then we need to push
        // the collection address onto our list of user's collections.
        if (userTokensStaked[userCollectionHash] == 0) {
            collectionStakerIndex[userCollectionHash] = collectionStakers[_collection].length;
            collectionStakers[_collection].push(msg.sender);
        }

        // Update the number of tokens that our user has staked
        unchecked {
            userTokensStaked[userCollectionHash] += tokensLength;
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
        delete collectionStakers[_collection][collectionStakerIndex[userCollectionHash]];

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
    function setSweepModifier(uint _sweepModifier) external onlyOwner {
        sweepModifier = _sweepModifier;
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

    function setUnderlyingToken(address _collection, address _token) external onlyOwner {
        underlyingTokenMapping[_collection] = _token;
    }

    function setCurrentEpoch(uint _currentEpoch) external {
        // TODO: Needs lockdown
        // require(msg.sender == address(treasury), 'Treasury only');
        currentEpoch = _currentEpoch;
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

    /**
     * Allows the contract to receive ERC721 tokens from our {Treasury}.
     */
    function onERC721Received(address, address, uint, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

}

