// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {ERC721Lockable} from '@floor/tokens/extensions/ERC721Lockable.sol';
import {CannotSetNullAddress} from '@floor/utils/Errors.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {INewCollectionWarOptions} from '@floor-interfaces/voting/NewCollectionWarOptions.sol';

/**
 * When a new collection is going to be voted in to the ecosystem, we set up a New Collection
 * War with a range of collections that will then be open to vote on. Votes will be made by
 * casting veFloor against a specific collection.
 *
 * There is the option of creating an exercisable option that will additionally generate a
 * voting power through a calculator. This is accomodated in this contract, but the logic
 * will be encapsulated in a separate contract.
 *
 * When the {EpochManager} determines that an epoch has ended, if there is an active New
 * Collection War, then `endFloorWar` will be called.
 */
contract NewCollectionWars is AuthorityControl, EpochManaged, INewCollectionWars {
    /// Internal contract mappings
    VeFloorStaking public immutable veFloor;

    /// Internal options contract mapping
    INewCollectionWarOptions public newCollectionWarOptions;

    /// Stores a collection of all the NewCollectionWars that have been started
    FloorWar public currentWar;
    FloorWar[] public wars;

    /// Stores the address of the collection that won a Floor War
    mapping(uint => address) public floorWarWinner;

    /// Stores the unlock epoch of a collection in a floor war
    mapping(bytes32 => uint) public collectionEpochLock;

    /// Stores if a collection has been flagged as ERC1155
    mapping(address => bool) public is1155;

    /// Stores the number of votes a user has placed against a war collection
    mapping(bytes32 => uint) public userVotes;

    /// Stores the floor spot price of a collection token against a war collection
    mapping(bytes32 => uint) public collectionSpotPrice;

    /// Stores the total number of votes against a war collection
    mapping(bytes32 => uint) public collectionVotes;
    mapping(bytes32 => uint) public collectionNftVotes;

    /// Stores which collection the user has cast their votes towards to allow for
    /// reallocation on subsequent votes if needed.
    mapping(bytes32 => address) public userCollectionVote;

    /**
     * Sets our internal contract addresses.
     */
    constructor(address _authority, address _veFloor) AuthorityControl(_authority) {
        if (_veFloor == address(0)) revert CannotSetNullAddress();
        veFloor = VeFloorStaking(_veFloor);
    }

    /**
     * Gets the index of the current war, returning 0 if none are set.
     */
    function currentWarIndex() public view returns (uint) {
        return currentWar.index;
    }

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     *
     * @param _user User address being checked
     *
     * @return Voting power of the user
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
    function userVotesAvailable(uint _war, address _user) public view returns (uint) {
        return userVotingPower(_user) - userVotes[keccak256(abi.encode(_war, _user))];
    }

    /**
     * Allows the user to cast 100% of their voting power against an individual
     * collection. If the user has already voted on the FloorWar then this will
     * additionally reallocate their votes.
     *
     * @param collection The address of the collection to cast vote against
     */
    function vote(address collection) external {
        // Ensure a war is currently running
        require(currentWar.index != 0, 'No war currently running');

        // Ensure the collection is part of the current war
        bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));
        require(isCollectionInWar(warCollection), 'Invalid collection');

        // Check if user has already voted. If they have, then we first need to
        // remove this existing vote before reallocating.
        bytes32 warUser = keccak256(abi.encode(currentWar.index, msg.sender));
        address userVote = userCollectionVote[warUser];
        if (userVote != address(0)) {
            unchecked {
                collectionVotes[keccak256(abi.encode(currentWar.index, userVote))] -= userVotes[warUser];
            }
        }

        // Ensure the user has enough votes available to cast
        uint votesAvailable = userVotingPower(msg.sender);

        unchecked {
            // Increase our tracked user amounts
            collectionVotes[warCollection] += votesAvailable;
            userVotes[warUser] = votesAvailable;
            userCollectionVote[warUser] = collection;
        }

        // Trigger our potential restake due to vote action
        veFloor.refreshLock(msg.sender);

        emit VoteCast(msg.sender, collection, userVotes[warUser], collectionVotes[warCollection]);
    }

    /**
     * Allows an approved contract to submit option-related votes against a collection
     * in the current war.
     *
     * @param sender The address of the user that staked the token
     * @param war The war index being voted against
     * @param collection The collection to cast the vote against
     * @param votes The voting power added from the option creation
     */
    function optionVote(address sender, uint war, address collection, uint votes) external {
        // Ensure that only our {NewCollectionWarOptions} contract is calling this function
        require(msg.sender == address(newCollectionWarOptions), 'Invalid caller');

        // Confirm that we are voting for the current war only
        require(war == currentWar.index, 'Invalid war');

        // Create our war collection hash
        bytes32 warCollection = keccak256(abi.encode(war, collection));

        unchecked {
            // Increment our vote counters
            collectionVotes[warCollection] += votes;
            collectionNftVotes[warCollection] += votes;
        }

        // Emit our event for stalkability
        emit NftVoteCast(sender, war, collection, collectionVotes[warCollection], collectionNftVotes[warCollection]);
    }

    /**
     * Revokes a user's current votes in the current war.
     *
     * @dev This is used when a user unstakes their floor
     *
     * @param account The address of the account that is having their vote revoked
     */
    function revokeVotes(address account) external onlyRole(VOTE_MANAGER) {
        // Ensure a war is currently running
        require(currentWar.index != 0, 'No war currently running');

        // Confirm that the collection being voted for is in the war
        bytes32 warUser = keccak256(abi.encode(currentWar.index, account));

        // Find the collection that the user has currently voted on
        address collection = userCollectionVote[warUser];

        // If the user has voted on a collection, then we can subtract the votes
        if (collection != address(0)) {
            bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));

            unchecked {
                collectionVotes[warCollection] -= userVotes[warUser];
                userVotes[warUser] = 0;
            }

            delete userCollectionVote[warUser];

            emit VoteRevoked(msg.sender, collection, collectionVotes[warCollection]);
        }
    }

    /**
     * Allow an authorised user to create a new floor war to start with a range of
     * collections from a specific epoch.
     *
     * @param epoch The epoch that the war will take place in
     * @param collections The collections that will be taking part
     * @param isErc1155 If the corresponding collection is an ERC1155 standard
     * @param floorPrices The ETH floor value of the corresponding collection
     */
    function createFloorWar(uint epoch, address[] calldata collections, bool[] calldata isErc1155, uint[] calldata floorPrices)
        external
        onlyOwner
        returns (uint)
    {
        // Confirm that we have enough collections passed
        uint collectionsLength = collections.length;
        require(collectionsLength > 1, 'Insufficient collections');

        // Confirm that we have an equal amount of parameters
        require(collectionsLength == isErc1155.length, 'Incorrect parameter counts');
        require(collectionsLength == floorPrices.length, 'Incorrect parameter counts');

        // Ensure that the Floor War is created with enough runway
        require(epoch > currentEpoch(), 'Floor War scheduled too soon');

        // Check if another floor war is already scheduled for this epoch
        require(!epochManager.isCollectionAdditionEpoch(epoch), 'War already exists at epoch');

        // Create the floor war
        uint warIndex = wars.length + 1;
        wars.push(
            FloorWar({
                index: warIndex,
                startEpoch: epoch,
                collections: collections
            })
        );

        bytes32 collectionHash;
        uint collectionLockEpoch = epoch + 1;
        for (uint i; i < collectionsLength;) {
            collectionHash = keccak256(abi.encode(warIndex, collections[i]));
            collectionSpotPrice[collectionHash] = floorPrices[i];
            collectionEpochLock[collectionHash] = collectionLockEpoch;
            is1155[collections[i]] = isErc1155[i];

            unchecked {
                ++i;
            }
        }

        // Schedule our floor war onto our {EpochManager}
        epochManager.scheduleCollectionAdditionEpoch(epoch, warIndex);

        emit CollectionAdditionWarCreated(epoch, collections, floorPrices);

        // Returns the war index
        return warIndex;
    }

    /**
     * Sets a scheduled {FloorWar} to be active.
     *
     * @dev This function is called by the {EpochManager} when a new epoch starts
     *
     * @param index The index of the {FloorWar} being started
     */
    function startFloorWar(uint index) external onlyEpochManager {
        // Ensure that we don't have a current war running
        require(currentWar.index == 0, 'War currently running');

        // Prevent an invalid index being passed as this symbolises that it doesn't exist
        require(wars.length >= index, 'Invalid war set to start');

        // Ensure that the index specified is scheduled to start at this epoch
        require(wars[index - 1].startEpoch == currentEpoch(), 'Invalid war set to start');

        // Set our current war
        currentWar = wars[index - 1];

        emit CollectionAdditionWarStarted(index);
    }

    /**
     * When the epoch has come to an end, this function will be called to finalise
     * the votes and decide which collection has won. This collection will then need
     * to be added to the {CollectionRegistry}.
     *
     * Any NFTs that have been staked will be timelocked for an additional epoch to
     * give the DAO time to exercise or reject any options.
     *
     * This function is called when an epoch ends via the {EpochManager}. The
     * `currentEpoch` will show as the epoch that is ending, not the value of the
     * epoch that is being entered.
     *
     * @dev We can't action this in one single call as we will need information about
     * the underlying NFTX token as well.
     *
     * @return highestVoteCollection The collection address that received the most votes
     */
    function endFloorWar() external onlyRole(EPOCH_TRIGGER) returns (address highestVoteCollection) {
        // Ensure that we have a current war running
        require(currentWar.index != 0, 'No war currently running');

        // Ensure that the war has had sufficient run time
        require(currentEpoch() >= currentWar.startEpoch, 'War epoch has not passed');

        // Find the collection that holds the top number of votes
        uint highestVoteCount;
        uint collectionsLength = currentWar.collections.length;

        for (uint i; i < collectionsLength;) {
            uint votes = collectionVotes[keccak256(abi.encode(currentWar.index, currentWar.collections[i]))];
            if (votes > highestVoteCount) {
                highestVoteCollection = currentWar.collections[i];
                highestVoteCount = votes;
            }

            unchecked {
                ++i;
            }
        }

        // Set our winner
        floorWarWinner[currentWar.index] = highestVoteCollection;

        unchecked {
            // Increment our winner lock by two epochs. One to allow the DAO to exercise, and the
            // second to allow Floor NFT holders to exercise.
            collectionEpochLock[keccak256(abi.encode(currentWar.index, highestVoteCollection))] += 2;
        }

        emit CollectionAdditionWarEnded(currentWar.index, highestVoteCollection);

        // Close the war
        delete currentWar;
    }

    /**
     * Allows us to update our collection floor prices if we have seen a noticable difference
     * since the start of the epoch. This will need to be called for this reason as the floor
     * price of the collection heavily determines the amount of voting power awarded when
     * creating an option.
     */
    function updateCollectionFloorPrice(address collection, uint floorPrice) external onlyOwner {
        // Prevent an invalid floor price breaking everything
        require(floorPrice != 0, 'Invalid floor price');

        // Ensure that we have a current war running
        require(currentWar.index != 0, 'No war currently running');

        // Ensure that the collection specified is valid
        bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));
        require(isCollectionInWar(warCollection), 'Invalid collection');

        // Update the floor price of the collection
        uint oldFloorPrice = collectionSpotPrice[warCollection];
        collectionSpotPrice[warCollection] = floorPrice;

        // Alter the vote count based on the percentage change of the floor price
        if (floorPrice == oldFloorPrice) {
            return;
        }

        // If the collection currently has no votes, we don't need to recalculate
        if (collectionNftVotes[warCollection] == 0) {
            return;
        }

        // If we have increase the floor price of the token, then we will need to increase the
        // relative votes.
        if (floorPrice > oldFloorPrice) {
            // Calculate the updated NFT vote power for the collection
            uint percentage = ((floorPrice * 1e18 - oldFloorPrice * 1e18) * 100) / oldFloorPrice;
            uint increase = (collectionNftVotes[warCollection] * percentage) / 100 / 1e18;
            uint newNumber = collectionNftVotes[warCollection] + increase;

            // Update our collection votes
            collectionVotes[warCollection] = collectionVotes[warCollection] - collectionNftVotes[warCollection] + newNumber;
            collectionNftVotes[warCollection] = newNumber;
        }
        // Otherwise, if we are reducing the floor price of the token, then we will instead be
        // decreasing the number of votes assigned.
        else {
            // Calculate the updated NFT vote power for the collection
            uint percentage = ((oldFloorPrice * 1e18 - floorPrice * 1e18) * 100) / oldFloorPrice;
            uint decrease = (collectionNftVotes[warCollection] * percentage) / 100 / 1e18;
            uint newNumber = collectionNftVotes[warCollection] - decrease;

            // Update our collection votes
            collectionVotes[warCollection] = collectionVotes[warCollection] - collectionNftVotes[warCollection] + newNumber;
            collectionNftVotes[warCollection] = newNumber;
        }
    }

    /**
     * Allows our options contract to be updated.
     *
     * @dev We allow this to be set to a zero-address to disable the functionality.
     *
     * @param _contract The new contract to use
     */
    function setOptionsContract(address _contract) external onlyOwner {
        newCollectionWarOptions = INewCollectionWarOptions(_contract);
        emit NewCollectionWarOptionsUpdated(_contract);
    }

    /**
     * Check if a collection is in a FloorWar.
     */
    function isCollectionInWar(bytes32 warCollection) public view returns (bool) {
        return collectionSpotPrice[warCollection] != 0;
    }
}
