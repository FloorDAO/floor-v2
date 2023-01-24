// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../authorities/AuthorityControl.sol';

import '../tokens/VaultXToken.sol';

import '../../interfaces/collections/CollectionRegistry.sol';
import '../../interfaces/strategies/BaseStrategy.sol';
import '../../interfaces/tokens/veFloor.sol';
import '../../interfaces/vaults/Vault.sol';
import '../../interfaces/vaults/VaultFactory.sol';
import '../../interfaces/voting/GaugeWeightVote.sol';

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

    /// Internal contract references
    ICollectionRegistry immutable collectionRegistry;
    IVaultFactory immutable vaultFactory;
    IVeFLOOR immutable veFloor;

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

    // Mapping collection address -> total amount.
    mapping(address => uint) public votes;

    // Store a list of collections each user has voted on to reduce the
    // number of iterations.
    mapping(address => address[]) public userVoteCollections;

    // Storage for yield calculations
    mapping(address => uint) internal yieldStorage;

    // Track the previous snapshot that was made
    uint public lastSnapshot;

    /**
     *
     */
    constructor(address _collectionRegistry, address _vaultFactory, address _veFloor, address _authority)
        AuthorityControl(_authority)
    {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        vaultFactory = IVaultFactory(_vaultFactory);
        veFloor = IVeFLOOR(_veFloor);
    }

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     */
    function userVotingPower(address _user) external view returns (uint) {
        return veFloor.balanceOf(_user);
    }

    /**
     * The total number of votes that a user has available, calculated by:
     *
     * ```
     * votesAvailable_ = balanceOf(_user) - SUM(userVotes.votes_)
     * ```
     */
    function userVotesAvailable(address _user) external view returns (uint votesAvailable_) {
        uint votesCast;

        // Iterate over all of our approved collections to check if they have more votes than
        // any of the collections currently stored.
        // TODO: Can this just be a global counter, rather than a loop?
        // e.g. a userVotesCast() function
        for (uint i; i < userVoteCollections[_user].length;) {
            votesCast += votes[userVoteCollections[_user][i]];
            unchecked {
                ++i;
            }
        }

        return this.userVotingPower(_user) - votesCast;
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
     */
    function vote(address _collection, uint _amount) external returns (uint totalVotes_) {
        require(_amount != 0, 'Cannot vote with zero amount');

        // Ensure the user has enough votes available to cast
        require(this.userVotesAvailable(msg.sender) >= _amount, 'Insufficient voting power');

        // Confirm that the collection being voted for is approved and valid, if we
        // aren't voting for a zero address (which symbolises FLOOR).
        if (_collection != FLOOR_TOKEN_VOTE) {
            require(collectionRegistry.isApproved(_collection), 'Collection not approved');
        }

        // If this is the first vote placed by a user, then we need to add it to
        // our list of user vote collections.
        if (userVotes[msg.sender][_collection] == 0) {
            userVoteCollections[msg.sender].push(_collection);
        }

        // Store our user's vote
        userVotes[msg.sender][_collection] += _amount;

        // Increment the collection vote amount
        votes[_collection] += _amount;

        emit VoteCast(_collection, _amount);

        return votes[_collection];
    }

    /**
     * Allows a user to revoke their votes from vaults. This will free up the
     * user's available votes that can subsequently be voted again with.
     */
    function revokeVotes(address[] memory _collection, uint[] memory _amount) external {
        uint length = _collection.length;

        // Validate our supplied array sizes
        require(length != 0, 'No collections supplied');
        require(length == _amount.length, 'Wrong amount count');

        // Iterate over our collections to revoke the user's vote amounts
        for (uint i; i < length;) {
            address collection = _collection[i];
            uint amount = _amount[i];

            // Ensure that our user has sufficient votes against the collection to revoke
            require(amount <= userVotes[msg.sender][collection], 'Insufficient votes to revoke');

            // Revoke votes from the collection
            userVotes[msg.sender][collection] -= amount;
            votes[collection] -= amount;

            // If the user no longer has a vote on the collection, then we can remove it
            // from the user's array.
            if (userVotes[msg.sender][collection] == 0) {
                _deleteUserCollectionVote(msg.sender, collection);
            }

            emit VoteCast(collection, votes[collection]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * Allows an authorised contract or wallet to revoke all user votes. This
     * can be called when the veFLOOR balance is reduced.
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
            votes[collection] -= amount;
            userVotes[_account][collection] = 0;

            // Delete the collection from our user's reference array
            _deleteUserCollectionVote(_account, collection);

            emit VoteCast(collection, votes[collection]);
        }
    }

    /**
     * The snapshot function will need to iterate over all collections that have
     * more than 0 votes against them. With that we will need to find each
     * vault's percentage share within each collection, in relation to others.
     *
     * This percentage share will instruct the {Treasury} on how much additional
     * FLOOR to allocate to the users staked in the vaults. These rewards will
     * become available in the {RewardLedger}.
     *
     * +----------------+-----------------+-------------------+-------------------+
     * | Voter          | veFloor         | Vote Weight       | Vault             |
     * +----------------+-----------------+-------------------+-------------------+
     * | Alice          | 30              | 40                | 1                 |
     * | Bob            | 20              | 30                | 2                 |
     * | Carol          | 40              | 55                | 3                 |
     * | Dave           | 20              | 40                | 2                 |
     * | Emily          | 25              | 35                | 0                 |
     * +----------------+-----------------+-------------------+-------------------+
     *
     * We then check against the `sampleSize` that has been set to only select the
     * first _x_ collections. We then find the vaults that align to the collection
     * and give them a sub-percentage of the collection's allocation based on the
     * total number of rewards generated.
     *
     * With the above information, and assuming that the {Treasury} has allocated
     * 1000 FLOOR tokens to be additionally distributed in this snapshot, we would
     * have the following allocations going to the vaults.
     *
     * +----------------+-----------------+-------------------+-------------------+
     * | Vault          | Votes Total     | Vote Percent      | veFloor Rewards   |
     * +----------------+-----------------+-------------------+-------------------+
     * | 0 (veFloor)    | 35              | 17.5%             | 175               |
     * | 1              | 40              | 20%               | 200               |
     * | 2              | 70              | 35%               | 350               |
     * | 3              | 55              | 27.5%             | 275               |
     * | 4              | 0               | 0%                | 0                 |
     * +----------------+-----------------+-------------------+-------------------+
     *
     * This would distribute the vaults allocated rewards against the staked
     * percentage in the vault. Any Treasury holdings that would be given in rewards
     * are just deposited into the {Treasury} as FLOOR, bypassing the {RewardsLedger}.
     *
     * In the following scenario:
     * PUNK A - 8 floor tokens in lifetime, 1 floor in last week
     * PUNK B - 2 floor tokens in lifetime, 2 floor in last week
     *
     * 100 FLOOR tokens being distributed to PUNK collection
     *
     * We have three options:
     *  1) We use lifetime rewards:
     *      A - 80 FLOOR
     *      B - 20 FLOOR
     *
     *  2) We use last week rewards:
     *      A - 33 FLOOR
     *      B - 66 FLOOR
     *
     *  3) We use exit velocity to give greater rewards to high yielding vaults,
     *     but to also reward consistently yielding vaults:
     *     ```
     *     share = (lifetime% + last week%) / vaultCount
     *     share = ( 100 / (lifetime% + last week%) ) / vaultCount
     *     ```
     *
     *      A - 42 FLOOR
     *      B - 58 FLOOR
     */
    function snapshot(uint tokens) external returns (address[] memory) {
        // Keep track of remaining tokens to avoid dust
        uint remainingTokens = tokens;

        // Set up our temporary collections array that will maintain our top voted collections
        address[] memory collections = _topCollections();
        uint collectionsLength = collections.length;

        // Iterate through our sample size of collections to get the total number of
        // votes placed that need to be used in distribution calculations to find
        // collection share.
        uint totalRelevantVotes;
        for (uint i; i < collectionsLength;) {
            totalRelevantVotes += votes[collections[i]];
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
                collectionRewards = (tokens * ((totalRelevantVotes * votes[collections[i]]) / (100 * 1e18))) / (10 * 1e18);
            }

            unchecked {
                remainingTokens -= collectionRewards;
            }

            // If we have the FLOOR token vote, then we just set a null vault
            if (collections[i] == FLOOR_TOKEN_VOTE) {
                // TODO: How do we distribute floor to users??

                // We don't need to process the rest of our loop
                unchecked { ++i; }
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
                // Get the rewards owed to the vault based on the yield share of the collection and
                // assign the rewards to the vault xToken
                uint vaultRewards = (collectionRewards * yieldStorage[collectionVaults[j]]) / yieldStorage[collections[i]];

                // We assume that the snapshot tokens have already been transferred to the rewards
                // ledger at this point
                VaultXToken(IVault(collectionVaults[j]).xToken()).distributeRewards(vaultRewards);

                unchecked { ++j; }
            }

            unchecked {
                ++i;
            }
        }

        // Update the snapshot time made
        lastSnapshot = block.timestamp;
        return collections;
    }

    function _topCollections() internal view returns (address[] memory) {
        // Set up our temporary collections array that will maintain our top voted collections
        address[] memory collections = new address[](sampleSize);

        // Get all of our collections
        address[] memory options = this.voteOptions();

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
                if (votes[options[i]] > votes[collections[j]]) {
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
     * ..
     */
    function setSampleSize(uint size) external onlyRole(VOTE_MANAGER) {
        require(size != 0, 'Sample size must be above 0');
        sampleSize = size;
    }

    /**
     * Provides a list of collection addresses that can be voted on.
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

    function _getCollectionVaultRewardsIndicator(address vault) internal returns (uint) {
        return IBaseStrategy(IVault(vault).strategy()).totalRewardsGenerated();
    }

    /**
     * ..
     */
    function _deleteUserCollectionVote(address account, address collection) internal returns (bool) {
        for (uint i; i < userVoteCollections[account].length;) {
            if (userVoteCollections[account][i] == collection) {
                delete userVoteCollections[account][i];
                return true;
            }

            unchecked {
                ++i;
            }
        }

        return false;
    }
}
