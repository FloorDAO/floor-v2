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
import {ERC721Lockable} from '@floor/tokens/extensions/ERC721Lockable.sol';

import {IFloorWars} from '@floor-interfaces/voting/FloorWars.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';


/**
 * ..
 */
contract FloorWars is AuthorityControl, EpochManaged, IERC1155Receiver, IERC721Receiver, IFloorWars, PullPayment {

    /// Internal contract mappings
    ITreasury immutable public treasury;
    VeFloorStaking immutable public veFloor;

    /// Internal floor NFT mapping
    address immutable public floorNft;

    /// Stores a collection of all the FloorWars that have been started
    FloorWar public currentWar;
    FloorWar[] public wars;

    /// Stores the address of the collection that won a Floor War
    mapping (uint => address) internal floorWarWinner;

    /// Stores the unlock epoch of a collection in a floor war
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

    /// Stores an array of tokens staked against a war collection
    /// @dev (War -> Collection -> Price) => Option[]
    mapping (bytes32 => Option[]) internal stakedTokens;

    /// Stores which collection the user has cast their votes towards to allow for
    /// reallocation on subsequent votes if needed.
    mapping (bytes32 => address) public userCollectionVote;

    /**
     * Sets our internal contract addresses.
     */
    constructor (
        address _authority,
        address _floorNft,
        address _treasury,
        address _veFloor
    ) AuthorityControl(_authority) {
        floorNft = _floorNft;
        treasury = ITreasury(_treasury);
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

        // Ensure the collection is part of the current war
        require(_isCollectionInWar(warCollection), 'Invalid collection');

        // Check if user has already voted. If they have, then we first need to
        // remove this existing vote before reallocating.
        if (userCollectionVote[warUser] != address(0)) {
            unchecked {
                collectionVotes[warCollection] -= userVotes[warUser];
            }
        }

        // Ensure the user has enough votes available to cast
        uint votesAvailable = this.userVotesAvailable(currentWar.index, msg.sender);

        unchecked {
            // Increase our tracked user amounts
            collectionVotes[warCollection] += votesAvailable;
            userVotes[warUser] += votesAvailable;
        }

        emit VoteCast(msg.sender, collection, userVotes[warUser], collectionVotes[warCollection]);
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

            emit VoteRevoked(msg.sender, collection, collectionVotes[warCollection]);
        }
    }

    /**
     * Allows the user to deposit their ERC721 or ERC1155 into the contract and
     * gain additional voting power based on the floor price attached to the
     * collection in the FloorWar.
     */
    function createOption(
        address collection,
        uint[] calldata tokenIds,
        uint40[] calldata amounts,
        uint56[] calldata exercisePercents
    ) external {
        // Confirm that the collection being voted for is in the war
        bytes32 warCollection = keccak256(abi.encode(currentWar.index, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');

        // Stores the voting power of each NFT
        uint votingPower;
        bytes32 optionHash;

        // Loop through our tokens
        uint tokenIdsLength = tokenIds.length;
        for (uint i; i < tokenIdsLength;) {
            // Ensure that our exercise price is equal to, or less than, the floor price for
            // the collection.
            require(exercisePercents[i] < 101, 'Exercise percent above 100%');

            // Create our encoded hash that we will store against tokens
            optionHash = keccak256(abi.encode(currentWar.index, collection, exercisePercents[i]));

            // Store our option with the token ID, plus the amount being staked against it
            /**
             * INITIAL GAS: 316378 - 95406 = 220972 ($40~)
             * NEW GAS: 227530 - 95406 = 132124 ($22~)
             */
            stakedTokens[optionHash].push(
                Option({
                    tokenId: tokenIds[i],
                    user: msg.sender,
                    amount: uint96(amounts[i])
                })
            );

            // Transfer the NFT into our contract
            if (is1155[collection]) {
                IERC1155(collection).safeTransferFrom(msg.sender, address(this), tokenIds[i], amounts[i], '');
            }
            else {
                IERC721(collection).transferFrom(msg.sender, address(this), tokenIds[i]);
            }

            unchecked {
                // Calculate the voting power generated by the option
                votingPower = this.nftVotingPower(collectionSpotPrice[warCollection], uint(exercisePercents[i])) * amounts[i];

                // Increment our vote counters
                collectionVotes[warCollection] += votingPower;
                collectionNftVotes[warCollection] += votingPower;
            }

            emit NftVoteCast(
                msg.sender,
                collection,
                stakedTokens[optionHash].length - 1,
                collectionVotes[warCollection],
                collectionNftVotes[warCollection]
            );

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
    function reclaimOptions(
        uint war,
        address collection,
        uint56[] calldata exercisePercents,
        uint[][] calldata indexes
    ) external {
        // Check that the war has ended and that the requested collection is a timelocked token
        bytes32 warCollection = keccak256(abi.encode(war, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');
        require(currentEpoch() >= collectionEpochLock[warCollection], 'Currently timelocked');

        // Loop through token IDs to start withdrawing
        for (uint i; i < exercisePercents.length;) {
            // Get the optionHash for the token requested
            bytes32 optionHash = keccak256(abi.encode(war, collection, exercisePercents[i]));

            // Now we can loop over our indexes to withdraw the full amounts, if the staker
            // matches the stored user value.
            for (uint index; index < indexes[i].length;) {
                // Check if the option belongs to the caller
                require(stakedTokens[optionHash][index].user == msg.sender, 'Caller is not staker');

                // Update the remaining amount to zero
                stakedTokens[optionHash][index].amount = 0;

                // Transfer the staked tokens to the staking user
                if (is1155[collection]) {
                    IERC1155(collection).safeTransferFrom(address(this), msg.sender, stakedTokens[optionHash][index].tokenId, stakedTokens[optionHash][index].amount, '');
                } else {
                    IERC721(collection).transferFrom(address(this), msg.sender, stakedTokens[optionHash][index].tokenId);
                }

                unchecked { ++index; }
            }

            unchecked { ++i; }
        }
    }

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseOptions(uint war, uint amount) external payable {
        // Get the collection that will be exercised based on the winner of the war
        address collection = floorWarWinner[war];
        require(collection != address(0), 'FloorWar has not ended');

        // Get our warCollection hash and our base price for exercising
        bytes32 warCollection = keccak256(abi.encode(war, collection));

        // Check exercise window matches for DAO
        require(collectionEpochLock[warCollection] - 2 == currentEpoch(), 'Outside exercise window');

        // Store our starting balance for event emit
        uint startBalance = amount;
        uint exerciseBasePrice = collectionSpotPrice[warCollection];

        // Since we cannot double break in Solidity, we need to track our internal break
        bool breakLoop;

        // Loop through all possible exercise percentage values to allow us to generate
        // our different hash values.
        for (uint exercisePercent; exercisePercent <= 100;) {
            bytes32 optionHash = keccak256(abi.encode(war, collection, exercisePercent));

            // Now we can loop over our staked tokens that match the exercise percent
            for (uint i; i < stakedTokens[optionHash].length;) {
                // Get our Option struct
                Option memory option = stakedTokens[optionHash][i];

                // Determine the quantity that we want to exercise
                uint quantity = option.amount;

                // If we have multiple amounts (ERC1155) then we need to calculate how
                // many of these we can exercise. We start from the highest possible and
                // iterate down.
                uint exercisePrice;
                do {
                    unchecked {
                        exercisePrice = (quantity * exerciseBasePrice * exercisePercent) / 100;

                        if (exercisePrice > amount) {
                            --quantity;
                        }
                    }
                } while (quantity != 0 && exercisePrice > amount);

                // If the exercise price even a single item, then we need to exit the
                // function as we can't afford anything else.
                if (quantity == 0) {
                    breakLoop = true;
                    break;
                }

                /**
                 * We now have the option for one of two approaches. We need to allocate
                 * funds to each user, and also transfer the token. Ideally we would batch
                 * up these requests, but it is unlikely that the additional gas costs in
                 * storing these batches calls would out-weigh the cost of transferring
                 * individually.
                 */

                // Pay the staker the amount that they requested into escrow
                _asyncTransfer(option.user, exercisePrice);

                // Transfer the NFT to our {Treasury}
                if (is1155[collection]) {
                    IERC1155(collection).safeTransferFrom(address(this), address(treasury), option.tokenId, quantity, '');
                } else {
                    IERC721(collection).transferFrom(address(this), address(treasury), option.tokenId);
                }

                unchecked {
                    // Update the staked token's amount to reflect the amount of quantity that
                    // have been exercised. This will mean that the data stays on chain, but if
                    // we try to resweep the epoch then we won't try to purchase nonexistant
                    // tokens.
                    option.amount -= uint96(quantity);

                    // Reduce our available amount by the exercise price
                    amount -= exercisePrice;

                    // Bump our iteration variable
                    ++i;
                }
            }

            // Check if we have actioned a break from our nested loop
            if (breakLoop) {
                break;
            }

            unchecked { ++exercisePercent; }
        }

        emit CollectionExercised(war, collection, startBalance - amount);
    }

    /**
     * Allows a Floor NFT token holder to exercise a staked NFT at the price that it
     * was listed at by the staking user.
     */
    function holderExerciseOptions(uint war, uint tokenId, uint exercisePercent, uint stakeIndex) external payable {
        // Get the collection that will be exercised based on the winner of the war
        address collection = floorWarWinner[war];
        require(collection != address(0), 'FloorWar has not ended');

        // Check exercise window matches for floor NFT holders
        bytes32 warCollection = keccak256(abi.encode(war, collection));
        require(collectionEpochLock[warCollection] - 1 == currentEpoch(), 'Outside exercise window');

        // Lock our token
        ERC721Lockable(floorNft).lock(msg.sender, tokenId, uint96(block.timestamp + 7 days));

        Option memory option = stakedTokens[keccak256(abi.encode(war, collection, exercisePercent))][stakeIndex];
        require(option.amount != 0, 'Nothing staked at index');

        // Determine the quantity that we want to exercise. This will always be 1 for holders.
        uint exercisePrice = (collectionSpotPrice[warCollection] * exercisePercent) / 100;

        // Pay the staker the amount that they requested into escrow
        _asyncTransfer(option.user, exercisePrice);

        // Transfer the NFT to the claiming user
        if (is1155[collection]) {
            IERC1155(collection).safeTransferFrom(address(this), msg.sender, option.tokenId, 1, '');
        } else {
            IERC721(collection).transferFrom(address(this), msg.sender, option.tokenId);
        }

        unchecked {
            // Update the staked token's amount to reflect the amount of quantity that
            // have been exercised. This will mean that the data stays on chain, but if
            // we try to resweep the epoch then we won't try to purchase nonexistant
            // tokens.
            option.amount -= 1;
        }

        emit CollectionExercised(war, collection, exercisePrice);
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
        uint collectionLockEpoch = epoch + 1;
        for (uint i; i < collectionsLength;) {
            collectionHash = keccak256(abi.encode(warIndex, collections[i]));
            collectionSpotPrice[collectionHash] = floorPrices[i];
            collectionEpochLock[collectionHash] = collectionLockEpoch;
            is1155[collections[i]] = isErc1155[i];

            unchecked { ++i; }
        }

        // Schedule our floor war onto our {EpochManager}
        epochManager.scheduleCollectionAddtionEpoch(epoch, warIndex);

        emit CollectionAdditionWarCreated(epoch, collections, floorPrices);

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
            // Increment our winner lock by two epochs. One to allow the DAO to exercise, and the
            // second to allow Floor NFT holders to exercise.
            collectionEpochLock[keccak256(abi.encode(currentWar.index, highestVoteCollection))] += 2;
        }

        emit CollectionAdditionWarEnded(currentWar.index);

        // Close the war
        delete currentWar;
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
