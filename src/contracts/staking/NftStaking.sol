// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {ABDKMath64x64} from '@floor/forks/ABDKMath64x64.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';
import {INftStakingStrategy} from '@floor-interfaces/staking/NftStakingStrategy.sol';
import {INftStakingBoostCalculator} from '@floor-interfaces/staking/NftStakingBoostCalculator.sol';

/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting through the calculation of a multiplier.
 */

contract NftStaking is EpochManaged, INftStaking, Pausable {

    struct StakedNft {
        uint epochStart;       // 256 / 256
        uint128 epochCount;    // 384 / 512
        uint128 tokensStaked;  // 512 / 512
    }

    /// Stores our modular NFT staking strategy.
    /// @dev When tokens are approved to be staked, it should call the `approvalAddress`
    /// on this contract to show the address to be approved.
    INftStakingStrategy public nftStakingStrategy;

    /// Stores a list of all strategies that have been used
    address[] public previousStrategies;

    /// Stores the boosted number of votes available to a user
    mapping(bytes32 => StakedNft) public stakedNfts;

    /// Stores an array of collections the user has currently staked NFTs for
    mapping(bytes32 => address[]) internal collectionStakers;
    mapping(bytes32 => uint) public collectionStakerIndex;

    /// Store the amount of discount applied to voting power of staked NFT
    uint16 public voteDiscount;
    uint64 public sweepModifier;

    /// Store our pricing executor that will determine the vote power of our NFT
    IBasePricingExecutor public pricingExecutor;

    /// Store our boost calculator contract that will calculate our modifier
    INftStakingBoostCalculator public boostCalculator;

    // Allow us to waive early unstake fees
    mapping(address => bool) public waiveUnstakeFees;

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

    /**
     * Gets the total boost value for collection, based on the amount of NFTs that have been
     * staked, as well as the value and duration at which they staked at.
     * @param _collection The address of the collection we are checking the boost multiplier of
     */
    function collectionBoost(address _collection) external view returns (uint) {
        return this.collectionBoost(_collection, currentEpoch());
    }

    /**
     * Gets the total boost value for collection, based on the amount of NFTs that have been
     * staked, as well as the value and duration at which they staked at.
     *
     * @param _collection The address of the collection we are checking the boost multiplier of
     * @param _epoch The epoch to get the value at
     *
     * @return uint The boost multiplier for the collection to 9 decimal places
     */
    function collectionBoost(address _collection, uint _epoch) external view returns (uint) {
        // Get the latest cached price of a collection. We need to get the number of FLOOR
        // tokens that this equates to, without the additional decimals.
        uint cachedFloorPrice = pricingExecutor.getLatestFloorPrice(nftStakingStrategy.underlyingToken(_collection));

        // Store our some variables for use throughout the loop for gas saves
        uint sweepPower;
        uint sweepTotal;

        uint currentEpoch = currentEpoch();
        bytes32 _collectionHash = collectionHash(_collection);
        uint length = collectionStakers[_collectionHash].length;

        // Loop through all stakes against a collection and summise the sweep power based on
        // the number staked and remaining epoch duration.
        for (uint i; i < length;) {
            (uint _sweepPower, uint _sweepTotal) = _calculateStakePower(
                collectionStakers[_collectionHash][i],
                _collection,
                cachedFloorPrice,
                currentEpoch,
                _epoch
            );

            unchecked {
                sweepPower += _sweepPower;
                sweepTotal += _sweepTotal;

                ++i;
            }
        }

        return boostCalculator.calculate(sweepPower, sweepTotal, sweepModifier);
    }

    function _calculateStakePower(
        address _user,
        address _collection,
        uint cachedFloorPrice,
        uint currentEpoch,
        uint targetEpoch
    ) internal view returns (uint sweepPower, uint sweepTotal) {
        // Load our user's staked NFTs
        StakedNft memory stakedNft = stakedNfts[this.hash(_user, _collection)];

        unchecked {
            // Get the remaining power of the stake based on remaining epochs
            if (currentEpoch < stakedNft.epochStart + stakedNft.epochCount) {
                // Determine our staked sweep power by calculating our epoch discount
                uint stakedSweepPower = (
                    ((stakedNft.tokensStaked * cachedFloorPrice * voteDiscount) / 10000)
                        * stakedNft.epochCount
                ) / LOCK_PERIODS[LOCK_PERIODS.length - 1];

                // Add the staked sweep power to our collection total
                sweepPower = stakedSweepPower - ((stakedSweepPower * (((targetEpoch - stakedNft.epochStart) * 1e9) / stakedNft.epochCount)) / 1e9);

                // Tally up our quantity total
                sweepTotal = stakedNft.tokensStaked;
            }
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
    function stake(address _collection, uint[] calldata _tokenId, uint8 _epochCount) external whenNotPaused {
        // Validate the number of epochs staked
        require(_epochCount < LOCK_PERIODS.length, 'Invalid epoch index');

        // Convert our user and collection to a bytes32 reference, creating a smaller 1d mapping,
        // as opposed to an otherwise 2d address mapping.
        bytes32 userCollectionHash = this.hash(msg.sender, _collection);

        // Get the number of tokens we will be transferring
        uint128 tokensLength = uint128(_tokenId.length);

        // Find the current value of the token
        uint tokenValue = pricingExecutor.getFloorPrice(nftStakingStrategy.underlyingToken(_collection));
        require(tokenValue != 0, 'Unknown token price');

        StakedNft memory stakedNft = stakedNfts[userCollectionHash];
        bytes32 _collectionHash = collectionHash(_collection);

        // If we don't currently have any tokens stored for the collection, then we need to push
        // the collection address onto our list of user's collections.
        if (stakedNft.tokensStaked == 0) {
            collectionStakerIndex[userCollectionHash] = collectionStakers[_collectionHash].length;
            collectionStakers[_collectionHash].push(msg.sender);
        }

        // Update the number of tokens that our user has staked
        unchecked {
            stakedNft.tokensStaked += tokensLength;
        }

        // Stake the token into our staking strategy
        nftStakingStrategy.stake(msg.sender, _collection, _tokenId);

        // Store the epoch starting epoch and the duration it is being staked for
        stakedNft.epochStart = currentEpoch();
        stakedNft.epochCount = LOCK_PERIODS[_epochCount];

        stakedNfts[userCollectionHash] = stakedNft;

        // Fire an event to show staked tokens
        emit TokensStaked(msg.sender, _tokenId.length, tokenValue, stakedNft.epochStart, LOCK_PERIODS[_epochCount]);
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param _collection The collection to unstake
     */
    function unstake(address _collection) external {
        _unstake(_collection, address(nftStakingStrategy));
    }

    function unstake(address _collection, address _nftStakingStrategy) external {
        _unstake(_collection, _nftStakingStrategy);
    }

    function _unstake(address _collection, address _nftStakingStrategy) internal {
        // Get our user collection hash
        bytes32 userCollectionHash = this.hash(msg.sender, _collection, _nftStakingStrategy);
        StakedNft memory stakedNft = stakedNfts[userCollectionHash];

        // Ensure that our user has staked tokens
        require(stakedNft.tokensStaked != 0, 'No tokens staked');

        // Determine the number of full NFTs that we can receive when unstaking, as well as any
        // dust remaining afterwards. These amounts will vary depending on the remaining period
        // when unstaking.
        uint numNfts;

        // To do this, we build up our `remainingPortionToUnstake` variable to account for all of
        // our returned value. We can then divide this by `1 ether` to find the number of whole
        // tokens that can be withdrawn. This will leave the `remainingPortionToUnstake` with just
        // the dust allocation.
        uint fees = _unstakeFees(_nftStakingStrategy, _collection, msg.sender);
        uint remainingPortionToUnstake = (stakedNft.tokensStaked * 1 ether) - fees;

        // We can now iterate over our whole tokens to determine the number of full ERC721s we can
        // withdraw, and how much will be left as ERC20.
        while (remainingPortionToUnstake >= 1 ether) {
            unchecked {
                remainingPortionToUnstake -= 1 ether;
                numNfts += 1;
            }
        }

        // Unstake the NFTs and remaining portion to our sender
        nftStakingStrategy.unstake(msg.sender, _collection, numNfts, remainingPortionToUnstake);

        // Remove our number of staked tokens for the collection
        delete stakedNfts[userCollectionHash];

        // Delete the collection from our user's collection array
        delete collectionStakers[collectionHash(_collection, _nftStakingStrategy)][collectionStakerIndex[userCollectionHash]];

        // Fire an event to show unstaked tokens
        emit TokensUnstaked(msg.sender, numNfts, remainingPortionToUnstake, fees);
    }

    /**
     * Calculates the amount in fees it would cost the calling user to unstake.
     *
     * @param _collection The collection being unstaked
     *
     * @return The amount in fees to unstake
     */
    function unstakeFees(address _collection) external view returns (uint) {
        return _unstakeFees(address(nftStakingStrategy), _collection, msg.sender);
    }

    /**
     * Calculates the amount in fees for a specific address to unstake from a collection.
     *
     * @param _collection The collection being unstaked
     * @param _sender The caller that is unstaking
     *
     * @return fees The amount in fees to unstake
     */
    function _unstakeFees(address _strategy, address _collection, address _sender) internal view returns (uint fees) {
        // If we are waiving fees, then nothing to pay
        if (waiveUnstakeFees[_strategy]) {
            return 0;
        }

        // Get our user collection hash
        StakedNft memory stakedNft = stakedNfts[this.hash(_sender, _collection, _strategy)];

        // If the user has no tokens staked, then no fees
        if (stakedNft.tokensStaked == 0) {
            return 0;
        }

        // If we have passed the full duration of the epoch staking, then no fees
        uint currentEpoch = currentEpoch();
        if (currentEpoch >= stakedNft.epochStart + stakedNft.epochCount) {
            return 0;
        }

        // Get our base early exit fee and determine the linear decline of the exit fees
        uint tokens = stakedNft.tokensStaked * 1 ether;
        fees = tokens - ((tokens * (currentEpoch - stakedNft.epochStart)) / stakedNft.epochCount);

        // Reduce the penalty by the modifier against the NFT sweep power. The modifier is
        // accurate to 9 decimal places, so we will need to account for that.
        if (sweepModifier != 0) {
            fees = (fees * (10e9 - sweepModifier)) / 10e9;
        }
    }

    /**
     * Allows rewards to be claimed from the staked NFT inventory positions.
     */
    function claimRewards(address _collection) external {
        nftStakingStrategy.claimRewards(_collection);
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
     * Allows the contract to waive early unstaking fees.
     *
     * @param _waiveUnstakeFees New value
     */
    function setWaiveUnstakeFees(address _strategy, bool _waiveUnstakeFees) external onlyOwner {
        waiveUnstakeFees[_strategy] = _waiveUnstakeFees;
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
     * Allows our staking strategy to be updated.
     */
    function setStakingStrategy(address _nftStakingStrategy) external onlyOwner {
        if (_nftStakingStrategy == address(nftStakingStrategy)) {
            return;
        }

        if (address(nftStakingStrategy) != address(0)) {
            previousStrategies.push(address(nftStakingStrategy));
        }

        nftStakingStrategy = INftStakingStrategy(_nftStakingStrategy);
    }

    /**
     * Creates a hash for the user collection referencing the current NFT staking strategy.
     */
    function hash(address _user, address _collection) external view returns (bytes32) {
        return keccak256(abi.encode(_user, _collection, address(nftStakingStrategy)));
    }

    /**
     * Creates a hash for the user collection referencing a custom NFT staking strategy.
     */
    function hash(address _user, address _collection, address _strategy) external pure returns (bytes32) {
        return keccak256(abi.encode(_user, _collection, _strategy));
    }

    /**
     * Calculates the hash for a collection and the current strategy.
     */
    function collectionHash(address _collection) internal view returns (bytes32) {
        return keccak256(abi.encode(_collection, address(nftStakingStrategy)));
    }

    /**
     * Calculates the has for a collection and a specific strategy.
     */
    function collectionHash(address _collection, address _strategy) internal pure returns (bytes32) {
        return keccak256(abi.encode(_collection, _strategy));
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
