// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {AuthorityControl} from '../authorities/AuthorityControl.sol';
import {CollectionNotApproved} from '../utils/Errors.sol';
import {VeFloorStaking} from '../staking/VeFloorStaking.sol';

import {ICollectionRegistry} from '../../interfaces/collections/CollectionRegistry.sol';
import {IBaseStrategy} from '../../interfaces/strategies/BaseStrategy.sol';
import {IVaultXToken} from '../../interfaces/tokens/VaultXToken.sol';
import {IVault} from '../../interfaces/vaults/Vault.sol';
import {IVaultFactory} from '../../interfaces/vaults/VaultFactory.sol';
import {IGaugeWeightVote} from '../../interfaces/voting/GaugeWeightVote.sol';

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
 * The GWV will allow users to assign their veFloor position to a vault, or
 * optionally case it to a veFloor, which will use a constant value. As the
 * vaults will be rendered as an address, the veFloor vote will take a NULL
 * address value.
 */
contract GaugeWeightVote is AuthorityControl, IGaugeWeightVote {
    /// Keep a store of the number of collections we want to reward pick per epoch
    uint public sampleSize = 5;

    /// Hardcoded address to map to the FLOOR token vault
    address public FLOOR_TOKEN_VOTE = address(1);
    address internal FLOOR_TOKEN_VOTE_XTOKEN;

    /// Internal contract references
    ICollectionRegistry immutable collectionRegistry;
    IVaultFactory immutable vaultFactory;
    VeFloorStaking immutable veFloor;

    /**
     * We will need to maintain an internal structure to map the voters against
     * a vault address so that we can determine vote growth and reallocation. We
     * will additionally maintain a mapping of vault address to total amount that
     * will better allow for snapshots to be taken for less gas.
     *
     * This will result in a slightly increased write, to provide a greatly
     * reduced read.
     */

    /**
     * A collection of votes that the user currently has placed.
     *
     * Mapping user address -> collection address -> amount.
     */
    mapping(address => mapping(address => uint)) private userVotes;
    mapping(address => uint) private totalUserVotes;

    /// Mapping collection address -> total amount.
    mapping(address => uint) internal voteStore;

    /// Store a list of collections each user has voted on to reduce the
    /// number of iterations.
    mapping(address => address[]) public userVoteCollections;

    /// Store a list of users that have cast a vote on each collection to
    /// reduce any required iterations.
    mapping(address => address[]) public collectionUsers;

    /// Storage for yield calculations
    mapping(address => uint) internal yieldStorage;

    /// Track the previous snapshot that was made
    uint public lastSnapshot;

    /**
     * Sets up our contract parameters.
     *
     * @param _collectionRegistry Address of our {CollectionRegistry}
     * @param _vaultFactory Address of our {VaultFactory}
     * @param _veFloor Address of our {veFLOOR}
     * @param _authority {AuthorityRegistry} contract address
     */
    constructor(address _collectionRegistry, address _vaultFactory, address _veFloor, address _authority) AuthorityControl(_authority) {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        vaultFactory = IVaultFactory(_vaultFactory);
        veFloor = VeFloorStaking(_veFloor);
    }

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     *
     * @param _user User address being checked
     */
    function userVotingPower(address _user) external view returns (uint) {
        return veFloor.balanceOf(_user);
    }

    /**
     * The total number of votes that a user has available.
     *
     * @param _user User address being checked
     *
     * @return uint Number of votes available to the user
     */
    function userVotesAvailable(address _user) external view returns (uint) {
        return this.userVotingPower(_user) - totalUserVotes[_user];
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
    function vote(address _collection, uint _amount) external {
        if (_amount == 0) {
            revert CannotVoteWithZeroAmount();
        }

        // Ensure the user has enough votes available to cast
        uint votesAvailable = this.userVotesAvailable(msg.sender);
        if (votesAvailable < _amount) {
            revert InsufficientVotesAvailable(_amount, votesAvailable);
        }

        // Confirm that the collection being voted for is approved and valid, if we
        // aren't voting for a zero address (which symbolises FLOOR).
        if (_collection != FLOOR_TOKEN_VOTE && !collectionRegistry.isApproved(_collection)) {
            revert CollectionNotApproved(_collection);
        }

        // If this is the first vote placed by a user, then we need to add it to
        // our list of user vote collections.
        if (userVotes[msg.sender][_collection] == 0) {
            userVoteCollections[msg.sender].push(_collection);
            collectionUsers[_collection].push(msg.sender);
        }

        // Store our user's vote
        userVotes[msg.sender][_collection] += _amount;
        totalUserVotes[msg.sender] += _amount;

        emit VoteCast(_collection, _amount);
    }

    /**
     * TODO: ..
     */
    function votes(address _collection) public view returns (uint votes_) {
        for (uint i; i < collectionUsers[_collection].length;) {
            unchecked {
                /**
                 * We have access to the time funds were locked and when they will unlock.
                 *
                 * From this, we need to get the amount of time that has already passed and
                 * them add this to the current block.timestamp. With this we can get an idea
                 * of what the current voting power is.
                 *
                 *
                 */

                (uint40 lockTime, uint40 unlockTime,) = veFloor.depositors(collectionUsers[_collection][i]);
                uint256 calcTime = block.timestamp + block.timestamp - lockTime;
                if (calcTime > unlockTime) {
                    calcTime = unlockTime;
                }
                votes_ += veFloor.votingPowerAt(
                    userVotes[collectionUsers[_collection][i]][_collection],
                    calcTime
                );

                ++i;
            }
        }
    }

    /**
     * Allows a user to revoke their votes from vaults. This will free up the
     * user's available votes that can subsequently be voted again with.
     *
     * @param _collection[] The collection address(es) being voted for
     * @param _amount[] The number of votes the caller is casting across the collections
     */
    function revokeVotes(address[] memory _collection, uint[] memory _amount) external {
        uint length = _collection.length;

        // Validate our supplied array sizes
        if (length == 0 || length != _amount.length) {
            revert InvalidCollectionsAndAmounts();
        }

        // Iterate over our collections to revoke the user's vote amounts
        for (uint i; i < length;) {
            address collection = _collection[i];
            uint amount = _amount[i];

            // Ensure that our user has sufficient votes against the collection to revoke
            if (amount > userVotes[msg.sender][collection]) {
                revert InsufficientVotesToRevoke(amount, userVotes[msg.sender][collection]);
            }

            // Revoke votes from the collection
            userVotes[msg.sender][collection] -= amount;
            totalUserVotes[msg.sender] -= amount;

            // If the user no longer has a vote on the collection, then we can remove it
            // from the user's array.
            if (userVotes[msg.sender][collection] == 0) {
                _deleteUserCollectionVote(msg.sender, collection);
            }

            // emit VoteCast(collection, votes[collection]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * Allows an authorised contract or wallet to revoke all user votes. This
     * can be called when the veFLOOR balance is reduced.
     *
     * @param _account The user having their votes revoked
     */
    function revokeAllUserVotes(address _account) external onlyRole(VOTE_MANAGER) {
        // Iterate over our collections to revoke the user's vote amounts
        for (uint i; i < userVoteCollections[_account].length;) {
            address collection = userVoteCollections[_account][i];
            uint amount = userVotes[_account][collection];

            unchecked {
                ++i;
            }

            // Ensure that our user has sufficient votes against the collection to revoke
            if (amount == 0) {
                continue;
            }

            // Revoke votes from the collection
            userVotes[_account][collection] = 0;

            // Delete the collection from our user's reference array
            _deleteUserCollectionVote(_account, collection);

            // emit VoteCast(collection, votes[collection]);
        }

        totalUserVotes[_account] = 0;
    }

    /**
     * The snapshot function will need to iterate over all collections that have
     * more than 0 votes against them. With that we will need to find each
     * vault's percentage share within each collection, in relation to others.
     *
     * This percentage share will instruct the {Treasury} on how much additional
     * FLOOR to allocate to the users staked in the vaults. These rewards will be
     * distributed via the {VaultXToken} attached to each {Vault} that implements
     * the collection that is voted for.
     *
     * We check against the `sampleSize` that has been set to only select the first
     * _x_ top voted collections. We find the vaults that align to the collection
     * and give them a sub-percentage of the collection's allocation based on the
     * total number of rewards generated within that collection.
     *
     * This would distribute the vaults allocated rewards against the staked
     * percentage in the vault. Any Treasury holdings that would be given in rewards
     * are just deposited into the {Treasury} as FLOOR tokens.
     *
     * @param tokens The number of tokens rewards in the snapshot
     *
     * @return address[] The collections that were granted rewards
     */
    // TODO: Should this be locked down to only run by epoch
    function snapshot(uint tokens) external returns (address[] memory) {
        // Keep track of remaining tokens to avoid dust
        uint remainingTokens = tokens;

        // Create our vote store
        address[] memory options = this.voteOptions();
        for (uint i; i < options.length;) {
            voteStore[options[i]] = this.votes(options[i]);
            unchecked { ++i; }
        }

        // Set up our temporary collections array that will maintain our top voted collections
        address[] memory collections = _topCollections(options);
        uint collectionsLength = collections.length;

        // Iterate through our sample size of collections to get the total number of
        // votes placed that need to be used in distribution calculations to find
        // collection share.
        uint totalRelevantVotes;
        for (uint i; i < collectionsLength;) {
            totalRelevantVotes += voteStore[collections[i]];
            unchecked {
                ++i;
            }
        }

        // Map consistant variables
        uint collectionRewards;

        // Iterate over our collections
        for (uint i; i < collectionsLength;) {
            // Reset the yield storage for the collection
            yieldStorage[collections[i]] = 0;

            // Calculate the reward allocation to be given to the collection based on
            // the number of votes from the total votes.
            if (i == collectionsLength - 1) {
                collectionRewards = remainingTokens;
            } else {
                collectionRewards = (tokens * ((totalRelevantVotes * voteStore[collections[i]]) / (100 * 1e18))) / (10 * 1e18);
            }

            unchecked {
                remainingTokens -= collectionRewards;
            }

            // If we have the FLOOR token collection vote, we can distribute to the assigned
            // xToken reward distributor.
            if (collections[i] == FLOOR_TOKEN_VOTE && FLOOR_TOKEN_VOTE_XTOKEN != address(0)) {
                // We will have a specific veFloor xToken at this point to distribute to
                IVaultXToken vaultXToken = IVaultXToken(FLOOR_TOKEN_VOTE_XTOKEN);
                vaultXToken.target().transfer(address(vaultXToken), collectionRewards);
                vaultXToken.distributeRewards(collectionRewards);

                // We don't need to process the rest of our loop
                unchecked {
                    ++i;
                }
                continue;
            }

            // Find the sub-percentage allocation given to each collection vault based on yield
            address[] memory collectionVaults = vaultFactory.vaultsForCollection(collections[i]);
            for (uint j; j < collectionVaults.length;) {
                uint rewards = _getCollectionVaultRewardsIndicator(collectionVaults[j]);

                yieldStorage[collectionVaults[j]] = rewards;
                yieldStorage[collections[i]] += rewards;

                unchecked {
                    ++j;
                }
            }

            for (uint j; j < collectionVaults.length;) {
                // If a top collection yielded 0 rewards, they aren't eligible for any rewards, and we
                // also need to avoid a 0 division in our code.
                if (yieldStorage[collections[i]] != 0) {
                    // Get the rewards owed to the vault based on the yield share of the collection and
                    // assign the rewards to the vault xToken
                    uint vaultRewards = (collectionRewards * yieldStorage[collectionVaults[j]]) / yieldStorage[collections[i]];

                    // We assume that the snapshot tokens have already been transferred to the rewards
                    // ledger at this point
                    IVaultXToken vaultXToken = IVaultXToken(IVault(collectionVaults[j]).xToken());
                    vaultXToken.target().transfer(address(vaultXToken), vaultRewards);
                    vaultXToken.distributeRewards(vaultRewards);
                }

                unchecked {
                    ++j;
                }
            }

            unchecked {
                ++i;
            }
        }

        // Update the snapshot time made
        lastSnapshot = block.timestamp;
        return collections;
    }

    /**
     * Finds the top voted collections based on the number of votes cast. This is quite
     * an intensive process for how simple it is, but essentially just orders creates an
     * ordered subset of the top _x_ voted collection addresses.
     *
     * @return Array of collections
     */
    function _topCollections(address[] memory options) internal view returns (address[] memory) {
        // Set up our temporary collections array that will maintain our top voted collections
        address[] memory collections = new address[](sampleSize);

        uint j;
        uint k;

        // Iterate over all of our approved collections to check if they have more votes than
        // any of the collections currently stored.
        for (uint i; i < options.length;) {
            // Loop through our currently stored collections and their votes to determine
            // if we want to shift things out.
            for (j = 0; j < sampleSize && j <= i;) {
                // If our collection has more votes than a collection in the sample size,
                // then we need to shift all other collections from beneath it.
                if (voteStore[options[i]] > voteStore[collections[j]]) {
                    break;
                }

                unchecked {
                    ++j;
                }
            }

            // If our `j` key is below the `sampleSize` we have requested, then we will
            // need to replace the key with our new collection and all subsequent keys will
            // shift down by 1, and any keys above the `sampleSize` will be deleted.
            for (k = sampleSize - 1; k > j;) {
                collections[k] = collections[k - 1];
                unchecked {
                    --k;
                }
            }

            // Update the new max element
            collections[k] = options[i];

            unchecked {
                ++i;
            }
        }

        return collections;
    }

    /**
     * Allows an authenticated caller to update the `sampleSize`.
     *
     * @dev This should be kept lower where possible for reduced gas spend
     *
     * @param size The new `sampleSize`
     */
    function setSampleSize(uint size) external onlyRole(VOTE_MANAGER) {
        if (size == 0) {
            revert SampleSizeCannotBeZero();
        }

        sampleSize = size;
    }

    /**
     * Provides a list of collection addresses that can be voted on. This will pull in
     * all approved collections as well as appending the {FLOOR} vote on the end, which
     * is a hardcoded address.
     *
     * @return collections_ Collections (and {FLOOR} vote address) that can be voted on
     */
    function voteOptions() external view returns (address[] memory collections_) {
        // Get all of our approved collections
        address[] memory _approvedCollections = collectionRegistry.approvedCollections();

        // Create a new array that will additionally accomodate zero address (FLOOR vote)
        collections_ = new address[](_approvedCollections.length + 1);

        // Add the approved collections to our new array
        uint i;
        for (i; i < _approvedCollections.length;) {
            collections_[i] = _approvedCollections[i];
            unchecked {
                ++i;
            }
        }

        // Finally, add our FLOOR vote address
        collections_[i] = FLOOR_TOKEN_VOTE;
    }

    /**
     * Returns a reward weighting for the vault, allowing us to segment the collection rewards
     * yield to holders based on this value. A vault with a higher indicator value will receive
     * a higher percentage of rewards allocated to the collection it implements.
     *
     * @param vault Address of the vault
     *
     * @return Reward weighting
     */
    function _getCollectionVaultRewardsIndicator(address vault) internal returns (uint) {
        return IVault(vault).lastEpochRewards();
    }

    /**
     * Removes a user's votes from a collection and refunds gas where possible.
     *
     * @param account Account having their votes revoked
     * @param collection The collection the votes are being revoked from
     */
    function _deleteUserCollectionVote(address account, address collection) internal {
        for (uint i; i < userVoteCollections[account].length;) {
            if (userVoteCollections[account][i] == collection) {
                delete userVoteCollections[account][i];
                break;
            }

            unchecked {
                ++i;
            }
        }

        for (uint i; i < collectionUsers[collection].length;) {
            if (collectionUsers[collection][i] == account) {
                delete collectionUsers[collection][i];
                break;
            }
        }
    }

    /**
     * Allows an authenticated called to update our {VaultXToken} address that is used
     * for {FLOOR} vote reward distributions.
     *
     * @param _xToken Address of our deployed {VaultXToken} contract
     */
    function setFloorXToken(address _xToken) public onlyRole(VOTE_MANAGER) {
        FLOOR_TOKEN_VOTE_XTOKEN = _xToken;
    }
}
