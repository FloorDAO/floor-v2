// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IVoteMarket} from '@floor-interfaces/bribes/VoteMarket.sol';
import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';

contract VoteMarket is EpochManaged, IVoteMarket, Pausable {

    /// Minimum number of epochs for a Bribe
    uint8 public constant MINIMUM_EPOCHS = 1;

    /// The percentage of bribes that will be sent to the DAO
    uint8 public constant DAO_FEE = 2;

    /// The recipient of any fees collected. This should be set to the {Treasury}, or
    /// to a specialist fee collection contract.
    address public immutable feeCollector;

    /// Store our claim merkles that define the available rewards for each user across
    /// all collections and bribes.
    mapping(uint => bytes32) epochMerkles;

    /// Store the total number of votes cast against each collection at each epoch
    mapping(bytes32 => uint) epochCollectionVotes;

    /// Stores a list of all bribes created, across past, live and future
    Bribe[] bribes;

    /// A mapping of collection addresses to an array of bribe array indexes
    mapping(address => uint[]) collectionBribes;

    /// Store a list of users that have claimed. Each encoded bytes represents a user that
    /// has claimed against a specific epoch and bribe ID.
    mapping(bytes32 => bool) internal userClaimed;

    /// Blacklisted addresses per bribe that aren't counted for rewards arithmetics.
    mapping(uint => mapping(address => bool)) public isBlacklisted;

    /// Track our bribe index iteration
    uint internal nextID;

    /// Oracle wallet that has permission to write merkles
    address public oracleWallet;

    /// Store our collection registry
    ICollectionRegistry public immutable collectionRegistry;

    constructor(address _collectionRegistry, address _oracleWallet, address _feeCollector) {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        oracleWallet = _oracleWallet;
        feeCollector = _feeCollector;
    }

    /**
     * Create a new bribe that can be applied to either a New Collection War or
     * Sweep War.
     *
     * @dev If a New Collection War bribe is being created, then the
     * `numberOfEpochs` value must be `1`.
     *
     * @param collection Address of the target collection.
     * @param rewardToken Address of the ERC20 used or rewards.
     * @param numberOfEpochs Number of periods.
     * @param maxRewardPerVote Target Bias for the Gauge.
     * @param totalRewardAmount Total Reward Added.
     * @param blacklist Array of addresses to blacklist.
     *
     * @return newBribeID of the bribe created.
     */
    function createBribe(
        address collection,
        address rewardToken,
        uint8 numberOfEpochs,
        uint maxRewardPerVote,
        uint totalRewardAmount,
        address[] calldata blacklist
    ) external whenNotPaused returns (uint newBribeID) {
        // Ensure that we aren't providing a NULL address
        require(rewardToken != address(0), 'Cannot be zero address');

        // Ensure we are supplying a bribe for at least the minimum number
        // of epochs.
        require(numberOfEpochs >= MINIMUM_EPOCHS, 'Invalid number of epochs');

        // If new collection epoch, force the number of epochs to be 1
        if (epochManager.isCollectionAdditionEpoch()) {
            require(numberOfEpochs == 1, 'New collection bribes can only last 1 epoch');
        }

        // Ensure that we have > 0 reward input
        require(totalRewardAmount != 0 && maxRewardPerVote != 0, 'Invalid amounts');

        // Transfer the rewards to the contracts
        ERC20(rewardToken).transferFrom(msg.sender, address(this), totalRewardAmount);

        unchecked {
            // Get the ID for that new Bribe and increment the nextID counter.
            newBribeID = nextID;
            ++nextID;
        }

        // Create our Bribe object at the new ID index
        bribes.push(
            Bribe({
                bribeId: newBribeID,
                collection: collection,
                rewardToken: rewardToken,
                startEpoch: currentEpoch(),
                numberOfEpochs: numberOfEpochs,
                maxRewardPerVote: maxRewardPerVote,
                totalRewardAmount: totalRewardAmount,
                blacklist: blacklist
            })
        );

        // Add the bribe to our collection mapping
        collectionBribes[collection].push(newBribeID);

        // Emit our Bribe creation event
        emit BribeCreated(newBribeID);

        // Add the addresses to the blacklist.
        uint length = blacklist.length;
        for (uint i; i < length;) {
            isBlacklisted[newBribeID][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Claims against any bribes for a user.
     */
    function claim(
        address account,
        uint[] calldata epoch,
        uint[] calldata bribeIds,
        address[] calldata collection,
        uint[] calldata votes,
        bytes32[][] calldata merkleProof
    ) external whenNotPaused {
        // Loop through all bribes assigned to the collection
        for (uint i; i < bribeIds.length;) {
            for (uint k; k < epoch.length;) {
                _claim(bribeIds[i], account, epoch[k], collection[k], votes[k], merkleProof[k]);
                unchecked {
                    ++k;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Claims against all bribes in a collection for a user.
     */
    function claimAll(
        address account,
        uint[] calldata epoch,
        address[] calldata collection,
        uint[] calldata votes,
        bytes32[][] calldata merkleProof
    ) external whenNotPaused {
        // Loop through all collection claims that the user is making
        for (uint i; i < collection.length;) {
            // Loop through all bribes assigned to the collection
            for (uint k; k < collectionBribes[collection[i]].length;) {
                _claim(collectionBribes[collection[i]][k], account, epoch[i], collection[i], votes[i], merkleProof[i]);
                unchecked {
                    ++k;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * Handles the internal logic to process a claim against a bribe.
     */
    function _claim(uint bribeId, address account, uint epoch, address collection, uint votes, bytes32[] calldata merkleProof) internal {
        // Check that the user has not already successfully claimed against this collection
        // at the specified epoch.
        bytes32 userClaimHash = _claimHash(bribeId, epoch);
        if (userClaimed[userClaimHash]) {
            return;
        }

        // Verify our merkle proof
        require(
            MerkleProof.verify(merkleProof, epochMerkles[epoch], keccak256(abi.encode(account, epoch, collection, votes))),
            'Invalid Merkle Proof'
        );

        // If the user is blacklisted from the bribe, then don't offer any reward
        if (isBlacklisted[bribeId][account]) {
            return;
        }

        // Load our bribe into memory as we won't be updating any content
        Bribe memory bribe = bribes[bribeId];

        // Calculate the reward amount per vote
        uint voteReward = bribe.maxRewardPerVote;
        bytes32 collectionHash = keccak256(abi.encode(collection, epoch));

        if (
            (bribe.maxRewardPerVote * epochCollectionVotes[collectionHash]) / (10 ** ERC20(bribe.rewardToken).decimals())
                > bribe.totalRewardAmount / bribe.numberOfEpochs
        ) {
            voteReward = ((bribe.totalRewardAmount / bribe.numberOfEpochs) * (10 ** ERC20(bribe.rewardToken).decimals()))
                / epochCollectionVotes[collectionHash];
        }

        // Determine the reward amount for the user
        uint amount = (votes * voteReward) / (10 ** ERC20(bribe.rewardToken).decimals());

        // Determine the amount of fee, if applicable, to return to the DAO for
        // facilitating the vote market.
        if (amount != 0) {
            if (DAO_FEE != 0) {
                uint feeAmount = amount * DAO_FEE / 100;
                amount -= feeAmount;

                // Transfer fees to the DAO
                ERC20(bribe.rewardToken).transfer(feeCollector, feeAmount);
            }

            // Transfer to account claiming the reward
            ERC20(bribe.rewardToken).transfer(account, amount);
        }

        // Mark our collection rewards for the epoch as claimed for the user
        userClaimed[userClaimHash] = true;

        // Emit our event
        emit Claimed(account, bribe.rewardToken, bribeId, amount, epoch);
    }

    /**
     * Allows our platform to increase the length of any sweep war bribes.
     *
     * @dev This will be called by the {EpochManager} when a New Collection War is created
     * to extend the duration any Sweep War bribes that would be active at that epoch.
     */
    function extendBribes(uint epoch) external onlyEpochManager {
        // Loop through approved collections
        address[] memory approvedCollections = collectionRegistry.approvedCollections();
        uint collectionsLength = approvedCollections.length;

        for (uint i; i < collectionsLength;) {
            // Find all bribes that have been assigned
            uint bribesLength = collectionBribes[approvedCollections[i]].length;
            for (uint k; k < bribesLength;) {
                Bribe memory bribe = bribes[collectionBribes[approvedCollections[i]][k]];

                // Check if the bribe falls over the epoch that we are inserting
                if (bribe.startEpoch + bribe.numberOfEpochs > epoch) {
                    // Increment the number of epochs that the bribe will last by 1, as
                    // we have essentially removed an epoch that they can be effective.
                    bribes[collectionBribes[approvedCollections[i]][k]].numberOfEpochs += 1;
                }

                unchecked { ++k; }
            }

            unchecked { ++i; }
        }
    }

    /**
     * Checks if the user has already claimed against a bribe at an epoch.
     */
    function hasUserClaimed(uint bribeId, uint epoch) external view returns (bool) {
        return userClaimed[_claimHash(bribeId, epoch)];
    }

    /**
     * Calculates our claim has for a bribe at an epoch.
     */
    function _claimHash(uint bribeId, uint epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(bribeId, bytes('_'), epoch));
    }

    /**
     * Allows our oracle wallet to upload a merkle root to define claims available against
     * a bribe when the epoch ends.
     */
    function registerClaims(uint epoch, bytes32 merkleRoot, address[] calldata collections, uint[] calldata collectionVotes) external onlyOracle {
        // Ensure that a merkleRoot has not already been set to this epoch
        require(epochMerkles[epoch] == '', 'merkleRoot already set');

        // Register the merkleRoot against our epoch
        epochMerkles[epoch] = merkleRoot;

        // Set our total votes so that we can calculate the per vote rewards
        for (uint i; i < collections.length;) {
            epochCollectionVotes[keccak256(abi.encode(collections[i], epoch))] = collectionVotes[i];
            unchecked {
                ++i;
            }
        }

        // Emit our claim registration event
        emit ClaimRegistered(epoch, merkleRoot);
    }

    /**
     * Sets our authorised oracle wallet that will upload bribe claims.
     */
    function setOracleWallet(address _oracleWallet) external onlyOwner {
        // We don't validate our oracle wallet address, we just assume the caller
        // isn't an idiot.
        oracleWallet = _oracleWallet;
    }

    /**
     * Allows our oracle wallet to expire collection bribes when they have expired.
     */
    function expireCollectionBribes(address[] calldata collection, uint[] calldata index) external onlyOracle {
        // Delete bribes based on the collection and index. This does not delete the
        // bribe structure, but instead just deletes the collection mapping so it is
        // no longner included in calculations or claims.
        //
        // @dev Warning: This does not sense check the information.
        for (uint i; i < collection.length;) {
            delete collectionBribes[collection[i]][index[i]];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Ensure that only our oracle wallet can call this function.
     */
    modifier onlyOracle {
        require(msg.sender == oracleWallet, 'Unauthorized caller');
        _;
    }
}
