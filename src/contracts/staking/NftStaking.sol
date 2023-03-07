// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {ABDKMath64x64} from '@floor/forks/ABDKMath64x64.sol';

import {INFTXUnstakingInventoryZap} from '@floor-interfaces/nftx/NFTXUnstakingInventoryZap.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';
import {INftStakingBoostCalculator} from '@floor-interfaces/staking/NftStakingBoostCalculator.sol';

/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting through the calculation of a multiplier.
 */

contract NftStaking is INftStaking, Ownable, Pausable {
    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;
    mapping(address => address) public underlyingXTokenMapping;

    /// Stores the epoch start time of staking, and the duration of the staking
    mapping(bytes32 => uint) public stakingEpochStart;
    mapping(bytes32 => uint) public stakingEpochCount;

    /// Stores the boosted number of votes available to a user
    mapping(bytes32 => uint) public userTokensStaked;

    /// Stores an array of collections the user has currently staked NFTs for
    mapping(address => address[]) internal collectionStakers;
    mapping(bytes32 => uint) public collectionStakerIndex;

    /// Store a mapping of NFTX vault address to vault ID for gas savings
    mapping(address => uint) internal cachedNftxVaultId;

    /// Store the amount of discount applied to voting power of staked NFT
    uint16 public voteDiscount;
    uint64 public sweepModifier;

    /// Store the current epoch, which will be updated by our internal calls to sync
    uint public currentEpoch;

    /// Store our pricing executor that will determine the vote power of our NFT
    IBasePricingExecutor public pricingExecutor;

    /// Store our boost calculator contract that will calculate our modifier
    INftStakingBoostCalculator public boostCalculator;

    /// Store our NFTX staking zaps
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /// Temp. user store for ERC721 receipt
    address private _nftReceiver;

    // Allow us to waive early unstake fees
    bool public waiveUnstakeFees;

    /// Set a list of locking periods that the user can lock for
    uint8[] public LOCK_PERIODS = [uint8(0), 4, 13, 26, 52, 78, 104];

    /**
     * Sets up our immutable contract addresses.
     */
    constructor(address _pricingExecutor, uint16 _voteDiscount) {
        require(_pricingExecutor != address(0), 'Address not zero');
        require(_voteDiscount < 10000, 'Must be less that 10000');

        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
        voteDiscount = _voteDiscount;
    }

    function collectionBoost(address _collection) external view returns (uint) {
        return this.collectionBoost(_collection, currentEpoch);
    }

    /**
     * Gets the total boost value for collection, based on the amount of NFTs that have been
     * staked, as well as the value and duration at which they staked at.
     *
     * @param _collection The address of the collection we are checking the boost multiplier of
     *
     * @return uint The boost multiplier for the collection to 9 decimal places
     */
    function collectionBoost(address _collection, uint _epoch) external view returns (uint) {
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
                    stakedSweepPower = (
                        ((userTokensStaked[userCollectionHash] * cachedFloorPrice * voteDiscount) / 10000)
                            * stakingEpochCount[userCollectionHash]
                    ) / LOCK_PERIODS[LOCK_PERIODS.length - 1];
                    epochModifier = ((_epoch - stakingEpochStart[userCollectionHash]) * 1e9) / stakingEpochCount[userCollectionHash];

                    // Add the staked sweep power to our collection total
                    sweepPower += stakedSweepPower - ((stakedSweepPower * epochModifier) / 1e9);

                    // Tally up our quantity total
                    sweepTotal += userTokensStaked[userCollectionHash];
                }

                ++i;
            }
        }

        return boostCalculator.calculate(sweepPower, sweepTotal, sweepModifier);
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
    function stake(address _collection, uint[] calldata _tokenId, uint8 _epochCount) external whenNotPaused {
        // Validate the number of epochs staked
        require(_epochCount < LOCK_PERIODS.length, 'Invalid epoch index');

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

            unchecked {
                ++i;
            }
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
        stakingEpochCount[userCollectionHash] = LOCK_PERIODS[_epochCount];

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

        // Ensure that our user has staked tokens
        require(userTokensStaked[userCollectionHash] != 0, 'No tokens staked');

        // Determine the number of full NFTs that we can receive when unstaking, as well as any
        // dust remaining afterwards. These amounts will vary depending on the remaining period
        // when unstaking.
        uint numNfts;

        // To do this, we build up our `remainingPortionToUnstake` variable to account for all of
        // our returned value. We can then divide this by `1 ether` to find the number of whole
        // tokens that can be withdrawn. This will leave the `remainingPortionToUnstake` with just
        // the dust allocation.
        uint remainingPortionToUnstake = (userTokensStaked[userCollectionHash] * 1 ether) - _unstakeFees(_collection, msg.sender);

        // We can now iterate over our whole tokens to determine the number of full ERC721s we can
        // withdraw, and how much will be left as ERC20.
        while (remainingPortionToUnstake >= 1 ether) {
            unchecked {
                remainingPortionToUnstake -= 1 ether;
                numNfts += 1;
            }
        }

        // Approve the max usage of the underlying token against the unstaking zap
        IERC20(underlyingXTokenMapping[_collection]).approve(address(unstakingZap), type(uint).max);

        // Set our NFT receiver so that our callback function can hook into the correct
        // recipient. We have to do this as NFTX doesn't allow a recipient to be specified
        // when calling the unstaking zap. This only needs to be done if we expect to
        // receive an NFT.
        if (numNfts != 0) {
            _nftReceiver = msg.sender;
        }

        // Unstake all inventory for the user for the collection. This forked version of the
        // NFTX unstaking zap allows us to specify the recipient, so we don't need to handle
        // any additional transfers.
        unstakingZap.unstakeInventory(_getVaultId(_collection), numNfts, remainingPortionToUnstake);

        // Transfer our remaining portion to the user
        IERC20(underlyingTokenMapping[_collection]).transfer(
            _nftReceiver, IERC20(underlyingTokenMapping[_collection]).balanceOf(address(this))
        );

        // After our NFTs have been unstaked, we want to make sure we delete the receiver
        delete _nftReceiver;

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

    function unstakeFees(address _collection) external view returns (uint) {
        return _unstakeFees(_collection, msg.sender);
    }

    /**
     * ..
     */
    function _unstakeFees(address _collection, address _sender) internal view returns (uint) {
        // Get our user collection hash
        bytes32 userCollectionHash = keccak256(abi.encode(_sender, _collection));

        // If we are waiving fees, then nothing to pay
        if (waiveUnstakeFees) {
            return 0;
        }

        // If the user has no tokens staked, then no fees
        uint tokens = userTokensStaked[userCollectionHash] * 1 ether;
        if (tokens == 0) {
            return 0;
        }

        // If we have passed the full duration of the epoch staking, then no fees
        if (currentEpoch >= stakingEpochStart[userCollectionHash] + stakingEpochCount[userCollectionHash]) {
            return 0;
        }

        return tokens - ((tokens * (currentEpoch - stakingEpochStart[userCollectionHash])) / stakingEpochCount[userCollectionHash]);
    }

    /**
     * Set our Vote Discount value to increase or decrease the amount of base value that
     * an NFT has.
     *
     * @dev The value is passed to 2 decimal place accuracy
     *
     * @param _voteDiscount The amount of vote discount to apply
     */
    function setVoteDiscount(uint16 _voteDiscount) external onlyOwner {
        require(_voteDiscount < 10000, 'Must be less that 10000');
        voteDiscount = _voteDiscount;
    }

    /**
     * In addition to the {setVoteDiscount} function, our sweep modifier allows us to
     * modify our resulting modifier calculation. A higher value will reduced the output
     * modifier, whilst reducing the value will increase it.
     *
     * @param _sweepModifier The amount to modify our multiplier
     */
    function setSweepModifier(uint64 _sweepModifier) external onlyOwner {
        require(_sweepModifier != 0);
        sweepModifier = _sweepModifier;
    }

    /**
     * Sets an updated pricing executor (needs to confirm an implementation function).
     *
     * @param _pricingExecutor Address of new {IBasePricingExecutor} contract
     */
    function setPricingExecutor(address _pricingExecutor) external onlyOwner {
        require(_pricingExecutor != address(0), 'Address not zero');
        pricingExecutor = IBasePricingExecutor(_pricingExecutor);
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
     * Allows our epoch to be set by the {Treasury}. This should be sent when our {Treasury} ends
     * the current epoch and moves to a new one.
     *
     * @param _currentEpoch The new, current epoch
     */
    function setCurrentEpoch(uint _currentEpoch) external {
        // TODO: Needs lockdown
        // require(msg.sender == address(treasury), 'Treasury only');
        currentEpoch = _currentEpoch;
    }

    /**
     * Allows a new boost calculator to be set.
     *
     * @param _boostCalculator The new boost calculator contract address
     */
    function setBoostCalculator(address _boostCalculator) external onlyOwner {
        require(_boostCalculator != address(0));
        boostCalculator = INftStakingBoostCalculator(_boostCalculator);
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
     * Allows rewards to be claimed from the staked NFT inventory positions.
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
    function onERC721Received(address, address, uint tokenId, bytes memory) public virtual returns (bytes4) {
        if (_nftReceiver != address(0)) {
            IERC721(msg.sender).safeTransferFrom(address(this), _nftReceiver, tokenId);
        }
        return this.onERC721Received.selector;
    }
}
