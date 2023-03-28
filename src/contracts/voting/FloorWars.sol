// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PullPayment} from '@openzeppelin/contracts/security/PullPayment.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IFloorWars} from '@floor-interfaces/voting/FloorWars.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';


/**
 * ..
 */

contract FloorWars is AuthorityControl, EpochManaged, IERC1155Receiver, IERC721Receiver, IFloorWars, PullPayment {

    /// Internal contract mappings
    ITreasury immutable public treasury;
    VeFloorStaking immutable public veFloor;

    /// Stores a collection of all the FloorWars that have been started
    FloorWar public currentWar;
    FloorWar[] public wars;

    /// ..
    mapping (uint => address) internal floorWarWinner;
    mapping (bytes32 => uint) internal collectionEpochLock;

    /// Stores if a collection has been flagged as ERC1155
    mapping (address => bool) internal is1155;

    /// Stores the number of votes a user has placed against a war collection
    mapping (bytes32 => uint) public userVotes;

    /// Stores the floor spot price of a collection token against a war collection
    mapping (bytes32 => uint) public collectionSpotPrice;

    /// Stores the total number of votes against a war collection
    mapping (bytes32 => uint) public collectionVotes;
    mapping (bytes32 => uint) public collectionNftVotes;

    /// Stores which collection the user has cast their votes towards to allow for
    /// reallocation on subsequent votes if needed.
    mapping (bytes32 => address) public userCollectionVote;

    /// Stores an array of tokens staked against a war collection
    mapping (bytes32 => StakedCollectionERC721) public stakedERC721s;
    mapping (bytes32 => StakedCollectionERC1155[]) public stakedERC1155s;

    // Stores the number of ERC1155 tokens stored by each user, for each war collection
    mapping (bytes32 => uint) internal erc1155Stakers;

    /**
     * Sets our internal contract addresses.
     */
    constructor (address _authority, address _treasury, address _veFloor) AuthorityControl(_authority) {
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
    function vote(address collection) external {
        // Ensure a war is currently running
        require(currentWar.index != 0, 'No war currently running');

        // Confirm that the collection being voted for is in the war
        bytes32 warUser = keccak256(abi.encode(currentWar.index, msg.sender));
        bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));

        require(_isCollectionInWar(warCollection), 'Invalid collection');

        // Check if user has already voted. If they have, then we first need to
        // remove this existing vote before reallocating.
        if (userCollectionVote[warUser] != address(0)) {
            unchecked {
                collectionVotes[warCollection] -= userVotes[warUser];
            }
        }

        unchecked {
            // Ensure the user has enough votes available to cast
            uint votesAvailable = this.userVotesAvailable(currentWar.index, msg.sender);

            // Increase our tracked user amounts
            collectionVotes[warCollection] += votesAvailable;
            userVotes[warUser] += votesAvailable;
        }
    }

    /**
     * ..
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
        }
    }

    /**
     * Allows the user to deposit their ERC721 or ERC1155 into the contract and
     * gain additional voting power based on the floor price attached to the
     * collection in the FloorWar.
     */
    function voteWithCollectionNft(address collection, uint[] calldata tokenIds, uint40[] calldata amounts, uint56[] calldata exercisePercents) external {
        // Confirm that the collection being voted for is in the war
        bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');

        // Get the voting power of the NFT
        uint votingPower;

        // Loop through our tokens
        for (uint i; i < tokenIds.length;) {
            // Ensure that our exercise price is equal to, or less than, the floor price for
            // the collection.
            require(exercisePercents[i] < 101, 'Exercise percent above 100%');

            // Transfer the NFT into our contract
            if (is1155[collection]) {
                IERC1155(collection).safeTransferFrom(msg.sender, address(this), tokenIds[i], amounts[i], '');

                stakedERC1155s[keccak256(abi.encode(currentWar.index, collection, tokenIds[i]))].push(
                    StakedCollectionERC1155(msg.sender, exercisePercents[i], amounts[i])
                );

                unchecked {
                    erc1155Stakers[keccak256(abi.encode(currentWar.index, collection, tokenIds[i], msg.sender))] += amounts[i];
                    votingPower = this.nftVotingPower(collectionSpotPrice[warCollection], uint(exercisePercents[i])) * amounts[i];
                }
            }
            else {
                IERC721(collection).transferFrom(msg.sender, address(this), tokenIds[i]);
                stakedERC721s[keccak256(abi.encode(currentWar.index, collection, tokenIds[i]))] = StakedCollectionERC721(msg.sender, exercisePercents[i]);

                unchecked {
                    votingPower = this.nftVotingPower(collectionSpotPrice[warCollection], uint(exercisePercents[i]));
                }
            }

            unchecked {
                // Increment our vote counters
                collectionVotes[warCollection] += votingPower;
                collectionNftVotes[warCollection] += votingPower;
            }

            unchecked { ++i; }
        }
    }

    /**
     * Allow an authorised user to create a new floor war to start with a range of
     * collections from a specific epoch.
     */
    function createFloorWar(uint epoch, address[] calldata collections, bool[] calldata isErc1155, uint[] calldata floorPrices) external onlyOwner returns (uint) {
        // Ensure that the Floor War is created with enough runway
        require(epoch > currentEpoch(), 'Floor War scheduled too soon');

        // Check if another floor war is already scheduled for this epoch
        require(!epochManager.isCollectionAdditionEpoch(epoch), 'Floor War already exists at this epoch');

        // Create the floor war
        uint warIndex = wars.length + 1;
        wars.push(FloorWar(warIndex, epoch, collections));

        // Create our spot prices for the collections
        uint collectionsLength = collections.length;
        require(collectionsLength > 1, 'Insufficient collections');

        bytes32 collectionHash;
        // TODO: y?
        uint collectionLockEpoch = currentEpoch() + 1;
        for (uint i; i < collectionsLength;) {
            collectionHash = keccak256(abi.encode(warIndex, collections[i]));
            collectionSpotPrice[collectionHash] = floorPrices[i];
            collectionEpochLock[collectionHash] = collectionLockEpoch;
            is1155[collections[i]] = isErc1155[i];

            unchecked { ++i; }
        }

        // Schedule our floor war onto our {EpochManager}
        epochManager.scheduleCollectionAddtionEpoch(epoch, warIndex);

        return warIndex;
    }

    /**
     * ..
     */
    function startFloorWar(uint index) external onlyEpochManager {
        // Ensure that we don't have a current war running
        require(currentWar.index == 0, 'War currently running');

        // Ensure that the index specified is scheduled to start at this epoch
        require(wars[index - 1].startEpoch == currentEpoch(), 'Invalid war set to start');

        // Set our current war
        currentWar = wars[index - 1];
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
    function endFloorWar() external onlyEpochManager returns (address highestVoteCollection) {
        // Ensure that we have a current war running
        require(currentWar.index != 0, 'No war currently running');

        // Find the collection that holds the top number of votes
        uint highestVoteCount;
        uint collectionsLength = currentWar.collections.length;

        for (uint i; i < collectionsLength;) {
            uint votes = collectionVotes[keccak256(abi.encode(currentWar.index, currentWar.collections[i]))];
            if (votes > highestVoteCount) {
                highestVoteCollection = currentWar.collections[i];
                highestVoteCount = votes;
            }

            unchecked { ++i; }
        }

        // Set our winner
        floorWarWinner[currentWar.index] = highestVoteCollection;

        unchecked {
            // Increment our winner lock by one epoch
            ++collectionEpochLock[keccak256(abi.encode(currentWar.index, highestVoteCollection))];
        }

        // Close the war
        delete currentWar;
    }

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseCollectionERC721s(uint war, uint[] calldata tokenIds) external payable onlyOwner {
        // Get the collection that will be exercised based on the winner of the war
        address collection = floorWarWinner[war];
        require(collection != address(0), 'FloorWar has not ended');

        bytes32 warCollection;
        bytes32 warCollectionToken;

        // Iterate over the tokenIds we want to exercise
        uint length = tokenIds.length;
        for (uint i; i < length;) {
            warCollection = keccak256(abi.encode(war, collection));
            warCollectionToken = keccak256(abi.encode(war, collection, tokenIds[i]));

            // Get all NFTs that were staked against the war collection
            StakedCollectionERC721 memory nft = stakedERC721s[warCollectionToken];

            // If we don't have a token match, skippers
            require(nft.staker != address(0), 'Token is not staked');

            // Pay the staker the amount that they requested into escrow
            _asyncTransfer(nft.staker, (collectionSpotPrice[warCollection] * nft.exercisePercent) / 100);

            // Transfer the NFT to our {Treasury}
            IERC721(collection).transferFrom(address(this), address(treasury), tokenIds[i]);
            delete stakedERC721s[warCollectionToken];

            unchecked { ++i; }
        }
    }

    /**
     * ..
     */
    function sortStaked1155s(StakedCollectionERC1155[] memory array) internal pure returns (StakedCollectionERC1155[] memory) {
        bool swapped;
        uint length = array.length;
        for (uint i = 1; i < length;) {
            swapped = false;
            for (uint j = 0; j < length - i;) {
                StakedCollectionERC1155 memory next = array[j + 1];
                StakedCollectionERC1155 memory actual = array[j];
                if (next.exercisePercent < actual.exercisePercent) {
                    array[j] = next;
                    array[j + 1] = actual;
                    swapped = true;
                }

                unchecked { ++j; }
            }

            if (!swapped) {
                return array;
            }

            unchecked { ++i; }
        }

        return array;
    }

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseCollectionERC1155s(uint war, uint[] calldata tokenIds, uint[] memory amount) external payable onlyOwner {
        // Get the collection that will be exercised based on the winner of the war
        address collection = floorWarWinner[war];
        require(collection != address(0), 'FloorWar has not ended');

        // Store our hashes once and update each time
        bytes32 warCollection;
        bytes32 warCollectionToken;
        bytes32 warCollectionTokenAmount;

        StakedCollectionERC1155[] memory orderedTokens;

        // Iterate over the tokenIds we want to exercise
        for (uint i; i < tokenIds.length;) {
            // Get our war collection token hash
            warCollection = keccak256(abi.encode(war, collection));
            warCollectionToken = keccak256(abi.encode(war, collection, tokenIds[i]));

            // For each token ID we need to sort through to order the prices in
            // ascending order.
            orderedTokens = sortStaked1155s(stakedERC1155s[warCollectionToken]);

            // Once we have the ordered tokens, we iterate over them and buy tokens
            // until we can't buy any more.
            uint amountToBuy;
            uint exercisePrice;
            uint totalToBuy;

            for (uint k; k < orderedTokens.length;) {
                warCollectionTokenAmount = keccak256(abi.encode(war, collection, tokenIds[i], orderedTokens[k].staker));

                // If the value is above the remaining available balance, then we can
                // move to the next token.
                exercisePrice = (collectionSpotPrice[warCollection] * orderedTokens[k].exercisePercent) / 100;
                amountToBuy = amount[i] / exercisePrice;
                if (amountToBuy == 0) {
                    break;
                }

                // If we can afford more than are staked, just take the staked amount
                if (amountToBuy > orderedTokens[k].amount) {
                    amountToBuy = orderedTokens[k].amount;
                }

                unchecked {
                    // Reduce our remaining balance by the number exercised
                    amount[i] -= exercisePrice * amountToBuy;

                    // Increment our total to buy
                    totalToBuy += amountToBuy;
                }

                // Pay the staker the amount that they requested into escrow
                _asyncTransfer(orderedTokens[k].staker, exercisePrice * amountToBuy);

                // Reduce the amount remaining against the staked 1155, deleting the stake if
                // we have exhausted the staked amount.
                erc1155Stakers[warCollectionTokenAmount] -= amountToBuy;

                unchecked { ++k; }
            }

            if (totalToBuy != 0) {
                // Transfer the NFT to our {Treasury}
                IERC1155(collection).safeTransferFrom(address(this), address(treasury), tokenIds[i], totalToBuy, '');
            }

            unchecked { ++i; }
        }
    }

    /**
     * If the FloorWar has not yet ended, or the NFT timelock has expired, then the
     * user reclaim the staked NFT and return it to their wallet.
     *
     *  start    current
     *  0        0         < locked
     *  0        1         < locked if won
     *  0        2         < free
     */
    function reclaimCollectionNft(uint war, address collection, uint[] calldata tokenIds) external {
        // Check that the war has ended and that the requested collection is a timelocked token
        require(floorWarWinner[war] != address(0), 'FloorWar has not ended');
        require(currentEpoch() > collectionEpochLock[keccak256(abi.encode(war, collection))], 'Currently timelocked');

        bytes32 warCollectionToken;

        // Loop through token IDs to start withdrawing
        for (uint i; i < tokenIds.length;) {
            warCollectionToken = keccak256(abi.encode(war, collection, tokenIds[i]));

            // Check if the NFT exists against
            StakedCollectionERC721 memory stakedNft = stakedERC721s[warCollectionToken];

            // Check that the sender is the staker
            require(stakedNft.staker == msg.sender, 'User is not staker');

            // Transfer the NFT back to the user
            if (is1155[collection]) {
                IERC1155(collection).safeTransferFrom(
                    address(this),
                    msg.sender,
                    tokenIds[i],
                    erc1155Stakers[keccak256(abi.encode(war, collection, tokenIds[i], msg.sender))],
                    ''
                );

                delete erc1155Stakers[keccak256(abi.encode(war, collection, tokenIds[i], msg.sender))];

                for (uint k; k < stakedERC1155s[warCollectionToken].length;) {
                    if (stakedERC1155s[warCollectionToken][k].staker == msg.sender) {
                        delete stakedERC1155s[warCollectionToken][k];
                    }

                    unchecked { ++k; }
                }
            }
            else {
                IERC721(collection).transferFrom(address(this), msg.sender, tokenIds[i]);
                delete stakedERC721s[warCollectionToken];
            }

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
    function nftVotingPower(uint spotPrice, uint exercisePercent) external pure returns (uint) {
        // If the user has matched our spot price, then we return full value
        if (exercisePercent == 100) {
            return spotPrice;
        }

        // The user cannot place an exercise price above the spot price that has been set. This
        // information should be validated internally before this function is called to prevent
        // this from happening.
        if (exercisePercent > 100) {
            return 0;
        }

        // Otherwise, if the user has set a lower spot price, then the voting power will be
        // increased as they are offering the NFT at a discount.
        unchecked {
            return spotPrice + ((spotPrice * (100 - exercisePercent)) / 100);
        }
    }

    /**
     * ..
     */
    function updateCollectionFloorPrice(address collection, uint floorPrice) external onlyOwner {
        // Prevent an invalid floor price breaking everything
        require(floorPrice != 0, 'Invalid floor price');

        // Ensure that we have a current war running
        require(currentWar.index != 0, 'No war currently running');

        // Ensure that the collection specified is valid
        bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');

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

        unchecked {
            // Calculate the updated NFT vote power for the collection
            uint percentage = ((floorPrice * 1e18 - oldFloorPrice * 1e18) * 100) / oldFloorPrice;
            uint increase = (collectionNftVotes[warCollection] * percentage) / 100  / 1e18;
            uint newNumber = (collectionNftVotes[warCollection] + increase);

            // Update our collection votes
            collectionVotes[warCollection] = collectionVotes[warCollection] - collectionNftVotes[warCollection] + newNumber;
            collectionNftVotes[warCollection] = newNumber;
        }
    }

    function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }

}
