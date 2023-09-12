// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {CannotSetNullAddress, CollectionNotApproved} from '@floor/utils/Errors.sol';

import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {INftStaking} from '@floor-interfaces/staking/NftStaking.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/// If a vote with a zero amount is sent
error CannotVoteWithZeroAmount();

/// If the caller attempts to vote with more than their available voting power
/// @param amount The amount of votes requested to cast
/// @param available The amount of votes available for the caller to cast
error InsufficientVotesAvailable(uint amount, uint available);

/// If an invalid collection and/or amount array are passed when revoking votes
error InvalidCollectionsAndAmounts();

/// If the caller attempts to revoke more votes than votes cast
/// @param amount The amount of votes requested to revoke
/// @param available The amount of votes available to be revoked
error InsufficientVotesToRevoke(uint amount, uint available);

/// If a sample size is attempted to be set to zero
error SampleSizeCannotBeZero();

/**
 * Each epoch, unless we have set up a {NewCollectionWar} to run, then a sweep war will
 * take place. This contract will handle the voting and calculations for these wars.
 *
 * When a Sweep War epoch ends, then the `snapshot` function will be called that finds the
 * top _x_ collections and their relative sweep amounts based on the votes cast.
 */
contract SweepWars is AuthorityControl, ISweepWars {

    /// Keep a store of the number of collections we want to reward pick per epoch
    uint public sampleSize = 5;

    /// Internal contract references
    ICollectionRegistry public immutable collectionRegistry;
    IStrategyFactory public immutable strategyFactory;
    VeFloorStaking public immutable veFloor;
    ITreasury public immutable treasury;
    INftStaking public nftStaking;

    /**
     * We will need to maintain an internal structure to map the voters against
     * a strategy address so that we can determine vote growth and reallocation. We
     * will additionally maintain a mapping of strategy address to total amount that
     * will better allow for snapshots to be taken for less gas.
     *
     * This will result in a slightly increased write, to provide a greatly
     * reduced read.
     */

    /// Store a mapping of the collection address to the number of votes
    mapping(address => int) public collectionVotes;

    /**
     * A collection of votes that the user currently has placed.
     *
     * Mapping user address -> collection address -> amount.
     */
    mapping(bytes32 => uint) private userForVotes;
    mapping(bytes32 => uint) private userAgainstVotes;
    mapping(address => uint) private totalUserVotes;

    /**
     * Sets up our contract parameters.
     *
     * @param _collectionRegistry Address of our {CollectionRegistry}
     * @param _strategyFactory Address of our {StrategyFactory}
     * @param _veFloor Address of our {veFLOOR}
     * @param _authority {AuthorityRegistry} contract address
     */
    constructor(address _collectionRegistry, address _strategyFactory, address _veFloor, address _authority, address _treasury)
        AuthorityControl(_authority)
    {
        if (_collectionRegistry == address(0) || _strategyFactory == address(0) || _veFloor == address(0) || _treasury == address(0)) {
            revert CannotSetNullAddress();
        }

        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        strategyFactory = IStrategyFactory(_strategyFactory);
        veFloor = VeFloorStaking(_veFloor);
        treasury = ITreasury(_treasury);
    }

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     *
     * @param _user User address being checked
     */
    function userVotingPower(address _user) public view returns (uint) {
        return veFloor.votingPowerOf(_user);
    }

    /**
     * The total number of votes that a user has available.
     *
     * @param _user User address being checked
     *
     * @return uint Number of votes available to the user
     */
    function userVotesAvailable(address _user) public view returns (uint) {
        // We shouldn't be in a situation where the user's total votes is above the
        // available voting power, but to avoid reverts..
        uint _userVotingPower = userVotingPower(_user);
        if (totalUserVotes[_user] >= _userVotingPower) {
            return 0;
        }

        return _userVotingPower - totalUserVotes[_user];
    }

    /**
     * Allows a user to cast a vote using their veFloor allocation. We don't
     * need to monitor transfers as veFloor can only be minted or burned, and
     * we check the voters balance during the `snapshot` call.
     *
     * A user can vote with a partial amount of their veFloor holdings, and when
     * it comes to calculating their voting power this will need to be taken into
     * consideration that it will be:
     *
     * ```
     * staked balance + (gains from staking * (total balance - staked balance)%)
     * ```
     *
     * The {Treasury} cannot vote with it's holdings, as it shouldn't be holding
     * any staked Floor.
     *
     * @param _collection The collection address being voted for
     * @param _amount The number of votes the caller is casting
     */
    function vote(address _collection, int _amount) external {
        if (_amount == 0) {
            revert CannotVoteWithZeroAmount();
        }

        // Get an absolute value of our cast amount
        uint absAmount = abs(_amount);

        // Ensure the user has enough votes available to cast
        uint votesAvailable = userVotesAvailable(msg.sender);
        if (votesAvailable < absAmount) {
            revert InsufficientVotesAvailable(absAmount, votesAvailable);
        }

        // Confirm that the collection being voted for is approved and valid, if we
        // aren't voting for a zero address (which symbolises FLOOR).
        if (!collectionRegistry.isApproved(_collection)) {
            revert CollectionNotApproved(_collection);
        }

        unchecked {
            // Increase our tracked user amounts
            if (_amount < 0) {
                userAgainstVotes[keccak256(abi.encode(msg.sender, _collection))] += absAmount;
            } else {
                userForVotes[keccak256(abi.encode(msg.sender, _collection))] += absAmount;
            }

            collectionVotes[_collection] += _amount;
            totalUserVotes[msg.sender] += absAmount;
        }

        // Trigger our potential restake due to vote action
        veFloor.refreshLock(msg.sender);

        emit VoteCast(msg.sender, _collection, _amount);
    }

    /**
     * Gets the number of votes for a collection at the current epoch.
     *
     * @param _collection The collection to check vote amount for
     *
     * @return votes_ The number of votes at the current epoch
     */
    function votes(address _collection) public view returns (int votes_) {
         votes_ = collectionVotes[_collection];

        // Pull in the additional voting power generated by NFT staking
        if (address(nftStaking) != address(0)) {
            votes_ = nftStaking.collectionBoost(_collection, votes_);
        }
    }

    /**
     * Allows a user to revoke their votes from strategies. This will free up the
     * user's available votes that can subsequently be voted again with.
     *
     * @param _collections[] The collection address(es) being revoked
     */
    function revokeVotes(address[] calldata _collections) external {
        _revokeVotes(msg.sender, _collections);
    }

    /**
     * Allows an authorised contract or wallet to revoke all user votes. This
     * can be called when the veFLOOR balance is reduced.
     *
     * @param _account The user having their votes revoked
     */
    function revokeAllUserVotes(address _account) external onlyRole(VOTE_MANAGER) {
        _revokeVotes(_account, voteOptions());
    }

    function _revokeVotes(address _account, address[] memory _collections) internal {
        // Pull our the number of collections we are revoking from for gas saves
        uint length = _collections.length;

        // Define variables ahead of our loop for gas saves
        bytes32 collectionHash;
        uint userCollectionVotes;

        // Iterate over our collections to revoke the user's vote amounts
        for (uint i; i < length;) {
            // Find the collection hash for the user and get their total for and against votes
            collectionHash = keccak256(abi.encode(_account, _collections[i]));
            userCollectionVotes = userForVotes[collectionHash] + userAgainstVotes[collectionHash];

            // Check that the user has voted for the collection in some way
            if (userCollectionVotes != 0) {
                // Update the power and power burn based on the new amount added
                collectionVotes[_collections[i]] += int(userAgainstVotes[collectionHash]);
                collectionVotes[_collections[i]] -= int(userForVotes[collectionHash]);

                // Reduce the number of votes cast by the user as a whole
                totalUserVotes[_account] -= userCollectionVotes;

                emit VotesRevoked(_account, _collections[i], userForVotes[collectionHash], userAgainstVotes[collectionHash]);

                // Set the number of for and against user votes back to 0 for the collection
                userForVotes[collectionHash] = 0;
                userAgainstVotes[collectionHash] = 0;
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * The snapshot function will need to iterate over all collections that have
     * more than 0 votes against them. With that we will need to find each
     * strategy percentage share within each collection, in relation to others.
     *
     * We check against the `sampleSize` that has been set to only select the first
     * _x_ top voted collections. We find the strategies that align to the collection
     * and give them a sub-percentage of the collection's allocation based on the
     * total number of rewards generated within that collection.
     *
     * @param tokens The number of tokens rewards in the snapshot
     *
     * @return address[] The collections that were granted rewards
     * @return amounts[] The vote values of each collection
     */
    function snapshot(uint tokens) external view returns (address[] memory, uint[] memory) {
        // Keep track of remaining tokens to avoid dust
        uint remainingTokens = tokens;

        // Set up our temporary collections array that will maintain our top voted collections
        (address[] memory collections, uint[] memory collectionVotePowers) = _topCollections();
        uint collectionsLength = collections.length;

        // Set up our amounts array that will hold the relevant share of the token allocation
        uint[] memory amounts = new uint[](collectionsLength);

        // Iterate through our sample size of collections to get the total number of
        // votes placed that need to be used in distribution calculations to find
        // collection share.
        uint totalRelevantVotes;
        for (uint i; i < collectionsLength;) {
            totalRelevantVotes += collectionVotePowers[i];
            unchecked {
                ++i;
            }
        }

        // Iterate over our collections
        for (uint i; i < collectionsLength;) {
            // Calculate the reward allocation to be given to the collection based on
            // the number of votes from the total votes.
            if (i == collectionsLength - 1) {
                amounts[i] = remainingTokens;
            } else {
                amounts[i] = (tokens * ((collectionVotePowers[i] * 1 ether) / totalRelevantVotes)) / 1 ether;
            }

            unchecked {
                remainingTokens -= amounts[i];
                ++i;
            }
        }

        return (collections, amounts);
    }

    /**
     * Finds the top voted collections based on the number of votes cast. This is quite
     * an intensive process for how simple it is, but essentially just orders creates an
     * ordered subset of the top _x_ voted collection addresses.
     *
     * @dev It may be possible to cache the `votes()` call value, but unsure of gas save
     *
     * @return Array of collections limited to sample size
     * @return Respective vote power for each collection
     */
    function _topCollections() internal view returns (address[] memory, uint[] memory) {
        // Get all of our collections
        address[] memory approvedCollections = voteOptions();
        uint length = approvedCollections.length;

        // We need to see which see if we have enough vote positive collections to fill the
        // sample size. If we don't, then we replace the sample size with. Whilst in this
        // loop we can also find vote amounts to save repeatedly calling them later on.
        uint positiveCollections;

        for (uint i; i < length;) {
            // If our vote amount is over zero, then we count this to compare against
            // the sample size later.
            if (votes(approvedCollections[i]) > 0) {
                unchecked {
                    ++positiveCollections;
                }
            }

            unchecked {
                ++i;
            }
        }

        // Check if the number of positive collections is smaller than the sample size. If it
        // is then we need to reduce the sample size we are looking at to only include positive
        // ones.
        uint _sampleSize = (positiveCollections > sampleSize) ? sampleSize : positiveCollections;

        // Set up our temporary collections array that will maintain our top voted collections
        address[] memory collections = new address[](_sampleSize);
        uint[] memory amounts = new uint[](_sampleSize);

        // If we have a zero value sample size, then we can just return our empty arrays
        if (_sampleSize == 0) {
            return (collections, amounts);
        }

        uint j;
        uint k;

        // Iterate over all of our approved collections to check if they have more votes than
        // any of the collections currently stored.
        for (uint i; i < length;) {
            // If we have a vote power that is not positive, then we don't need to process
            // any further logic as we definitely won't be including the collection in our
            // response.
            int _votes = votes(approvedCollections[i]);
            if (_votes <= 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            // Loop through our currently stored collections and their votes to determine
            // if we want to shift things out.
            for (j = 0; j < _sampleSize && j <= i;) {
                // If our collection has more votes than a collection in the sample size,
                // then we need to shift all other collections from beneath it.
                if (collections[j] == address(0) || _votes > votes(collections[j])) {
                    break;
                }

                unchecked {
                    ++j;
                }
            }

            // Only inject the value into our response if it is within the sample size window
            if (j < _sampleSize) {
                // If our `j` key is below the `_sampleSize` we have requested, then we will
                // need to replace the key with our new collection and all subsequent keys will
                // shift down by 1, and any keys above the `_sampleSize` will be deleted.
                for (k = _sampleSize - 1; k > j;) {
                    collections[k] = collections[k - 1];
                    amounts[k] = amounts[k - 1];

                    unchecked {
                        --k;
                    }
                }

                // Update the new max element and update the corresponding vote power. We can safely
                // cast our `amounts` value to a `uint` as it will always be a positive number.
                collections[k] = approvedCollections[i];
                amounts[k] = uint(_votes);
            }

            unchecked {
                ++i;
            }
        }

        return (collections, amounts);
    }

    /**
     * Allows an authenticated caller to update the `sampleSize`.
     *
     * @dev This should be kept lower where possible for reduced gas spend
     *
     * @param size The new `sampleSize`
     */
    function setSampleSize(uint size) external onlyRole(VOTE_MANAGER) {
        if (size == 0) revert SampleSizeCannotBeZero();

        sampleSize = size;
    }

    /**
     * Allows our {NftStaking} contract to be updated.
     *
     * @param _nftStaking The new {NftStaking} contract address
     */
    function setNftStaking(address _nftStaking) external onlyRole(VOTE_MANAGER) {
        if (_nftStaking == address(0)) revert CannotSetNullAddress();
        nftStaking = INftStaking(_nftStaking);
        emit NftStakingUpdated(_nftStaking);
    }

    /**
     * Provides a list of collection addresses that can be voted on. This will pull in
     * all approved collections, which should include the {FLOOR} token as well.
     *
     * @return collections_ Collections (and {FLOOR}) that can be voted on
     */
    function voteOptions() public view returns (address[] memory) {
        return collectionRegistry.approvedCollections();
    }

    /**
     * Math helper function to allow us to get the absolute value of an int
     */
    function abs(int x) private pure returns (uint) {
        return x >= 0 ? uint(x) : uint(-x);
    }
}
