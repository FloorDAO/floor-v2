// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PullPayment} from '@openzeppelin/contracts/security/PullPayment.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {INftVotingPowerCalculator} from '@floor/voting/calculators/NewCollectionNftOptionVotingPower.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';
import {ERC721Lockable} from '@floor/tokens/extensions/ERC721Lockable.sol';

import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {INewCollectionWarOptions} from '@floor-interfaces/voting/NewCollectionWarOptions.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/**
 * Expanding upon the logic in the {NewCollectionWar} contract, this allows for options to
 * be created by staking a full-price or discounted NFT that can be exercised by the DAO or
 * Floor NFT holders.
 */
contract NewCollectionWarOptions is EpochManaged, IERC1155Receiver, IERC721Receiver, INewCollectionWarOptions, PullPayment {
    /// Internal contract mappings
    ITreasury public immutable treasury;
    INewCollectionWars public immutable newCollectionWars;

    /// Internal floor NFT mapping
    address public immutable floorNft;

    /// Internal NFT Option Calculator
    INftVotingPowerCalculator public nftVotingPowerCalculator;

    /// Stores the number of votes a user has placed against a war collection
    mapping(bytes32 => uint) public userVotes;

    /// Stores an array of tokens staked against a war collection
    /// @dev (War -> Collection -> Price) => Option[]
    mapping(bytes32 => Option[]) internal stakedTokens;

    /**
     * Sets our internal contract addresses.
     */
    constructor(address _floorNft, address _treasury, address _newCollectionWars) {
        floorNft = _floorNft;
        newCollectionWars = INewCollectionWars(_newCollectionWars);
        treasury = ITreasury(_treasury);
    }

    /**
     * Allows the user to deposit their ERC721 or ERC1155 into the contract and
     * gain additional voting power based on the floor price attached to the
     * collection in the FloorWar.
     */
    function createOption(uint war, address collection, uint[] calldata tokenIds, uint40[] calldata amounts, uint56[] calldata exercisePercents)
        external
    {
        // Confirm that the collection being voted for is in the war
        bytes32 warCollection = keccak256(abi.encode(war, collection));
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
            optionHash = keccak256(abi.encode(war, collection, exercisePercents[i]));

            // Store our option with the token ID, plus the amount being staked against it
            stakedTokens[optionHash].push(Option({tokenId: tokenIds[i], user: msg.sender, amount: uint96(amounts[i])}));

            // Transfer the NFT into our contract
            if (newCollectionWars.is1155(collection)) {
                IERC1155(collection).safeTransferFrom(msg.sender, address(this), tokenIds[i], amounts[i], '');
            } else {
                IERC721(collection).transferFrom(msg.sender, address(this), tokenIds[i]);
            }

            unchecked {
                // Calculate the voting power generated by the option
                votingPower = this.nftVotingPower(war, collection, newCollectionWars.collectionSpotPrice(warCollection), uint(exercisePercents[i])) * amounts[i];
                newCollectionWars.optionVote(msg.sender, war, collection, votingPower);

                ++i;
            }
        }
    }

    /**
     * If the FloorWar has not yet ended, or the NFT timelock has expired, then the
     * user reclaim the staked NFT and return it to their wallet.
     *
     *  start    current
     *  0        0         < locked
     *  0        1         < locked if won for DAO
     *  0        2         < locked if won for Floor NFT holders
     *  0        3         < free
     */
    function reclaimOptions(uint war, address collection, uint56[] calldata exercisePercents, uint[][] calldata indexes) external {
        // Check that the war has ended and that the requested collection is a timelocked token
        bytes32 warCollection = keccak256(abi.encode(war, collection));
        require(_isCollectionInWar(warCollection), 'Invalid collection');
        require(currentEpoch() >= newCollectionWars.collectionEpochLock(warCollection), 'Currently timelocked');

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
                if (newCollectionWars.is1155(collection)) {
                    IERC1155(collection).safeTransferFrom(
                        address(this), msg.sender, stakedTokens[optionHash][index].tokenId, stakedTokens[optionHash][index].amount, ''
                    );
                } else {
                    IERC721(collection).transferFrom(address(this), msg.sender, stakedTokens[optionHash][index].tokenId);
                }

                unchecked {
                    ++index;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseOptions(uint war, uint amount) external payable {
        // Get the collection that will be exercised based on the winner of the war
        address collection = newCollectionWars.floorWarWinner(war);
        require(collection != address(0), 'FloorWar has not ended');

        // Get our warCollection hash and our base price for exercising
        bytes32 warCollection = keccak256(abi.encode(war, collection));

        // Check exercise window matches for DAO
        require(newCollectionWars.collectionEpochLock(warCollection) - 2 == currentEpoch(), 'Outside exercise window');

        // Store our starting balance for event emit
        uint startBalance = amount;
        uint exerciseBasePrice = newCollectionWars.collectionSpotPrice(warCollection);

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
                if (newCollectionWars.is1155(collection)) {
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

            unchecked {
                ++exercisePercent;
            }
        }

        emit CollectionExercised(war, collection, startBalance - amount);
    }

    /**
     * Allows a Floor NFT token holder to exercise a staked NFT at the price that it
     * was listed at by the staking user.
     */
    function holderExerciseOptions(uint war, uint tokenId, uint56 exercisePercent, uint stakeIndex) external payable {
        // Get the collection that will be exercised based on the winner of the war
        address collection = newCollectionWars.floorWarWinner(war);
        require(collection != address(0), 'FloorWar has not ended');

        // Check exercise window matches for floor NFT holders
        bytes32 warCollection = keccak256(abi.encode(war, collection));
        require(newCollectionWars.collectionEpochLock(warCollection) - 1 == currentEpoch(), 'Outside exercise window');

        // Ensure that a token exists at the index requested
        require(stakedTokens[keccak256(abi.encode(war, collection, exercisePercent))].length > stakeIndex, 'Nothing staked at index');
        Option memory option = stakedTokens[keccak256(abi.encode(war, collection, exercisePercent))][stakeIndex];
        require(option.amount != 0, 'Nothing staked at index');

        // Lock our token
        ERC721Lockable(floorNft).lock(msg.sender, tokenId, uint96(block.timestamp + 7 days));

        // Determine the quantity that we want to exercise. This will always be 1 for holders.
        uint exercisePrice = (newCollectionWars.collectionSpotPrice(warCollection) * exercisePercent) / 100;

        // Pay the staker the amount that they requested into escrow
        _asyncTransfer(option.user, exercisePrice);

        // Transfer the NFT to the claiming user
        if (newCollectionWars.is1155(collection)) {
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
     * Check if a collection is in a FloorWar.
     */
    function _isCollectionInWar(bytes32 warCollection) internal view returns (bool) {
        return newCollectionWars.isCollectionInWar(warCollection);
    }

    /**
     * Determines the voting power given by a staked NFT based on the requested
     * exercise price and the spot price.
     */
    function nftVotingPower(uint war, address collection, uint spotPrice, uint exercisePercent) external view returns (uint) {
        // If we don't have a calculator in place for this, then we cannot calculate
        require(address(nftVotingPowerCalculator) != address(0), 'Cannot currently create options');

        // Calculate our option voting power
        return nftVotingPowerCalculator.calculate(war, collection, spotPrice, exercisePercent);
    }

    /**
     * Allows the calculator used to determine the `votingPower` to be updated.
     *
     * @param _calculator The address of the new calculator
     */
    function setNftVotingPowerCalculator(address _calculator) external onlyOwner {
        nftVotingPowerCalculator = INftVotingPowerCalculator(_calculator);
    }

    /**
     * Allows ERC721's to be received via safeTransfer calls.
     */
    function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * Allows ERC1155's to be received via safeTransfer calls.
     */
    function onERC1155Received(address, address, uint, uint, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * Allows batched ERC1155's to be received via safeTransfer calls.
     */
    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * Inform other contracts that we support the 721 and 1155 interfaces.
     */
    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}