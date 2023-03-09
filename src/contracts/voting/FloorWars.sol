// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';


/**
 * NOTES:
 *  - Can we add a token ID to the bytes -> struct mapping? This would remove loops and the
 *    tokenId from the struct.
 *  - We can also drop the lock epoch as this will always be +1 of the corresponding war epoch.
 *  - Need the ability to revoke a users votes in an epoch
 */


contract FloorWars is Ownable {

    /// ..
    ITreasury immutable public treasury;
    VeFloorStaking immutable public veFloor;

    /**
     * Stores information about the NFT that has been staked. This allows either
     * the DAO to exercise the NFT, or for the initial staker to reclaim it.
     */
    struct StakedCollectionNft {
        address staker;
        uint exercisePrice;
    }

    /**
     * For each FloorWar that is created, this structure will be created. When
     * the epoch ends, the FloorWar will remain and will be updated with information
     * on the winning collection and the votes attributed to each collection.
     */
    struct FloorWar {
        // On creation
        address[] collections;
        bool[] erc1155;
        uint startEpoch;

        // On complete
        address winner;
        uint[] votes;
        bool ended;
    }

    /// Stores a collection of all the FloorWars that have been started
    FloorWar[] public wars;

    /// Stores the number of votes a user has placed against a war collection
    mapping (bytes32 => uint) public userVotes;

    /// Stores the floor spot price of a collection token against a war collection
    mapping (bytes32 => uint) public collectionSpotPrice;

    /// Stores the total number of votes against a war collection
    mapping (bytes32 => uint) public collectionVotes;

    /// Stores an array of tokens staked against a war collection
    mapping (bytes32 => StakedCollectionNft) public stakedNfts;

    /// Stores the current epoch enforced by the {Treasury}
    uint public currentEpoch;

    /**
     * Sets our internal contract addresses.
     */
    constructor (address _treasury, address _veFloor) {
        treasury = ITreasury(_treasury);
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
    function userVotesAvailable(uint _war, address _user) external view returns (uint) {
        return this.userVotingPower(_user) - userVotes[keccak256(abi.encode(_war, _user))];
    }

    /**
     * Allows the user to cast 100% of their voting power against an individual
     * collection. If the user has already voted on the FloorWar then this will
     * additionally reallocate their votes.
     */
    function vote(uint war, address collection) external {
        require(war < wars.length, 'Invalid index');

        // Confirm that the collection being voted for is in the war
        bytes32 warCollection = keccak256(abi.encode(war, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');

        unchecked {
            // Ensure the user has enough votes available to cast
            uint votesAvailable = this.userVotesAvailable(war, msg.sender);

            // Increase our tracked user amounts
            collectionVotes[warCollection] += votesAvailable;
            userVotes[keccak256(abi.encode(war, msg.sender))] += votesAvailable;
        }
    }

    /**
     * Allows the user to deposit their ERC721 or ERC1155 into the contract and
     * gain additional voting power based on the floor price attached to the
     * collection in the FloorWar.
     */
    function voteWithCollectionNft(uint war, address collection, uint[] calldata tokenIds, uint[] calldata exercisePrice) external {
        require(war < wars.length, 'Invalid index');

        // Confirm that the collection being voted for is in the war
        bytes32 warCollection = keccak256(abi.encode(war, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');

        // Loop through our tokens
        for (uint i; i < tokenIds.length;) {
            // Transfer the NFT into our contract
            IERC721(collection).transferFrom(msg.sender, address(this), tokenIds[i]);

            unchecked {
                // Get the voting power of the NFT
                uint votingPower = this.nftVotingPower(collectionSpotPrice[warCollection], exercisePrice[i]);

                // Increment our vote counters
                collectionVotes[warCollection] += votingPower;
                userVotes[keccak256(abi.encode(war, msg.sender))] += votingPower;
            }

            // Store our staked NFT struct data
            stakedNfts[keccak256(abi.encode(war, collection, tokenIds[i]))] = StakedCollectionNft(msg.sender, exercisePrice[i]);

            unchecked { ++i; }
        }
    }

    /**
     * Allow an authorised user to create a new floor war to start with a range of
     * collections from a specific epoch.
     */
    function createFloorWar(uint epoch, address[] calldata collections, bool[] calldata isErc1155, uint[] calldata floorPrices) external onlyOwner returns (uint war) {
        // Create our new FloorWar
        FloorWar memory floorWar;
        floorWar.collections = collections;
        floorWar.erc1155 = isErc1155;
        floorWar.startEpoch = epoch;
        floorWar.votes = new uint[](collections.length);

        // Store our FloorWar
        wars.push(floorWar);

        // Get our newly created index
        war = wars.length - 1;

        // Create our spot prices
        for (uint i; i < collections.length;) {
            collectionSpotPrice[keccak256(abi.encode(war, collections[i]))] = floorPrices[i];
            unchecked { ++i; }
        }
    }

    /**
     * When the epoch has come to an end, this function will be called to finalise
     * the votes and decide which collection has won. This collection will then need
     * to be added to the {CollectionRegistry}.
     *
     * Any NFTs that have been staked will be timelocked for an additional epoch to
     * give the DAO time to exercise or reject any options.
     *
     * @dev We can't action this in one single call as we will need information about
     * the underlying NFTX token as well.
     */
    function endFloorWar(uint war) external returns (address highestVoteCollection) {
        require(war < wars.length, 'Invalid index');

        // Ensure the war has ended based on epoch
        FloorWar memory floorWar = wars[war];
        require(floorWar.startEpoch < currentEpoch, 'FloorWar has not ended');

        // Ensure the epoch hasn't already been ended
        require(!floorWar.ended, 'FloorWar end already actioned');

        // Find the collection that holds the top number of votes
        uint highestVoteCount;

        for (uint i; i < floorWar.collections.length;) {
            uint votes = collectionVotes[keccak256(abi.encode(war, floorWar.collections[i]))];
            floorWar.votes[i] = votes;

            if (votes > highestVoteCount) {
                highestVoteCollection = floorWar.collections[i];
                highestVoteCount = votes;
            }

            unchecked { ++i; }
        }

        // Set our winner
        wars[war].winner = highestVoteCollection;
        wars[war].ended = true;

        // Write our vote results
        wars[war].votes = floorWar.votes;
    }

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseCollectionNfts(uint war, address collection, uint[] calldata tokenIds) external {
        require(war < wars.length, 'Invalid index');

        // Ensure the collection won the war
        require(wars[war].winner == collection, 'Collection did not win the FloorWar');

        bytes32 warCollectionToken;

        // Iterate over the tokenIds we want to exercise
        for (uint i; i < tokenIds.length;) {
            warCollectionToken = keccak256(abi.encode(war, collection, tokenIds[i]));

            // Get all NFTs that were staked against the war collection
            StakedCollectionNft memory nft = stakedNfts[warCollectionToken];

            // If we don't have a token match, skippers
            if (nft.staker == address(0)) {
                revert('Token is not staked');
            }

            // Pay the staker the amount that they requested
            (bool success, ) = payable(nft.staker).call{value: nft.exercisePrice}('');
            require(success, 'Address: unable to send value, recipient may have reverted');

            // Transfer the NFT to our {Treasury}
            IERC721(collection).transferFrom(address(this), address(treasury), tokenIds[i]);

            // We can delete the stake reference now that it has been processed
            delete stakedNfts[warCollectionToken];

            unchecked { ++i; }
        }
    }

    /**
     * If the FloorWar has not yet ended, or the NFT timelock has expired, then the
     * user reclaim the staked NFT and return it to their wallet.
     *
     *  start    current
     *  0        0         < free
     *  0        1         < locked if won
     *  0        2         < free
     */
    function reclaimCollectionNft(uint war, address collection, uint[] calldata tokenIds) external {
        require(war < wars.length, 'Invalid index');

        FloorWar memory floorWar = wars[war];

        // Check that the war has ended and that the requested collection is a timelocked token
        if (floorWar.winner == collection && floorWar.startEpoch + 1 == currentEpoch) {
            revert('Currently timelocked');
        }

        bytes32 warCollection;
        bytes32 warCollectionToken;

        // Loop through token IDs to start withdrawing
        for (uint i; i < tokenIds.length;) {
            warCollectionToken = keccak256(abi.encode(war, collection, tokenIds[i]));

            // Check if the NFT exists against
            StakedCollectionNft memory stakedNft = stakedNfts[warCollectionToken];

            // Check that the sender is the staker
            require(stakedNft.staker == msg.sender, 'User is not staker');

            // Transfer the NFT back to the user
            IERC721(collection).transferFrom(address(this), msg.sender, tokenIds[i]);

            if (floorWar.startEpoch == currentEpoch) {
                warCollection = keccak256(abi.encode(war, collection));

                // Get the voting power of the NFT
                uint votingPower = this.nftVotingPower(collectionSpotPrice[warCollection], stakedNft.exercisePrice);

                // Increment our vote counters
                collectionVotes[warCollection] -= votingPower;
                userVotes[keccak256(abi.encode(war, msg.sender))] -= votingPower;
            }

            delete stakedNfts[warCollectionToken];

            unchecked { ++i; }
        }
    }

    /**
     * Check if a collection is in a FloorWar.
     */
    function _isCollectionInWar(bytes32 warCollection) internal view returns (bool) {
        return collectionSpotPrice[warCollection] != 0;
    }

    /**
     * Determines the voting power given by a staked NFT based on the requested
     * exercise price and the spot price.
     */
    function nftVotingPower(uint spotPrice, uint exercisePrice) external pure returns (uint) {
        // If the user has matched our spot price, then we return full value
        if (exercisePrice == spotPrice) {
            return spotPrice;
        }

        // If the user has set a higher exercise price that the spot price, then the amount
        // of voting power they are assigned will be lower as they are offering the NFT at
        // a premium.
        if (exercisePrice > spotPrice) {
            unchecked {
                // Our formula doesn't allow a more than 2x pricing equivalent
                if (exercisePrice > spotPrice * 2) {
                    return 0;
                }

                return spotPrice - ((exercisePrice - spotPrice) / (spotPrice / (exercisePrice - spotPrice)));
            }
        }

        // Otherwise, if the user has set a lower spot price, then the voting power will be
        // increased as they are offering the NFT at a discount.
        unchecked {
            return spotPrice + ((spotPrice - exercisePrice) / (spotPrice / (spotPrice - exercisePrice)));
        }
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

}
