// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import {IVoteMarket} from '../../interfaces/bribes/VoteMarket.sol';

contract VoteMarket is IVoteMarket, Ownable, Pausable {

    event BribeCreated(uint bribeId, address rewardToken, uint numberOfEpochs, uint maxRewardPerVote, uint rewardPerEpoch, uint totalRewardAmount);
    event Claimed(address account, address rewardToken, uint bribeId, uint amount, uint epoch);
    event ClaimRegistered(uint epoch, bytes32 merkleRoot);

    /// Minimum number of epochs for a Bribe
    uint8 public constant MINIMUM_EPOCHS = 1;

    /// The percentage of bribes that will be sent to the DAO
    uint8 public constant DAO_FEE = 2;

    /// The recipient of any fees collected. This should be set to the {Treasury}, or
    /// to a specialist fee collection contract.
    address public feeCollector;

    /// Store our claim merkles that define the available rewards for each user across
    /// all collections and bribes.
    mapping (uint => bytes32) epochMerkles;

    /// Stores a list of all bribes created, across past, live and future
    Bribe[] bribes;

    /// A mapping of collection addresses to an array of bribe array indexes
    mapping (address => uint[]) collectionBribes;

    /// Store a list of users that have claimed. Each encoded bytes represents a user that
    /// has claimed against a specific epoch and collection.
    mapping(bytes32 => bool) internal userClaimed;

    /// Blacklisted addresses per bribe that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// Track our bribe index iteration
    uint internal nextID;

    /// Oracle wallet that has permission to write merkles
    address public oracleWallet;

    constructor (address _oracleWallet) {
        oracleWallet = _oracleWallet;
    }

    /**
     * Create a new bribe.
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
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata blacklist
    ) external whenNotPaused returns (uint256 newBribeID) {
        // Ensure that we aren't providing a NULL address
        require(rewardToken != address(0), 'Cannot be zero address');

        // Ensure we are supplying a bribe for at least the minimum number
        // of epochs.
        require(numberOfEpochs > MINIMUM_EPOCHS, 'Invalid number of epochs');

        // Ensure that we have > 0 reward input
        require(totalRewardAmount != 0 && maxRewardPerVote != 0, 'Invalid amounts');

        // Transfer the rewards to the contracts
        ERC20(rewardToken).transferFrom(msg.sender, address(this), totalRewardAmount);

        unchecked {
            // Get the ID for that new Bribe and increment the nextID counter.
            newBribeID = nextID;
            ++nextID;
        }

        // Calculate our reward amount per epoch by taking the total amount and dividing
        // it by the number of epochs requested.
        uint256 rewardPerEpoch = totalRewardAmount / numberOfEpochs;
        uint256 currentEpoch = 0;

        // Create our Bribe object at the new ID index
        bribes[newBribeID] = Bribe({
            bribeId: newBribeID,
            collection: collection,
            rewardToken: rewardToken,
            startEpoch: currentEpoch,
            numberOfEpochs: numberOfEpochs,
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            blacklist: blacklist
        });

        // Add the bribe to our collection mapping
        collectionBribes[collection].push(newBribeID);

        // Emit our Bribe creation event
        emit BribeCreated(
            newBribeID,
            rewardToken,
            numberOfEpochs,
            maxRewardPerVote,
            rewardPerEpoch,
            totalRewardAmount
        );

        // Add the addresses to the blacklist.
        uint256 length = blacklist.length;
        for (uint256 i; i < length;) {
            isBlacklisted[newBribeID][blacklist[i]] = true;
            unchecked { ++i; }
        }
    }

    function claim(address account, uint[] calldata epoch, address[] calldata collection, uint[] calldata votes, bytes32[][] calldata merkleProof) external whenNotPaused {
        // Loop through all collection claims that the user is making
        for (uint i; i < collection.length;) {
            // Check that the user has not already successfully claimed against this collection
            // at the specified epoch.
            bytes32 userClaimHash = claimHash(collection[i], epoch[i]);
            if (userClaimed[userClaimHash]) {
                continue;
            }

            // Loop through all bribes assigned to the collection
            for (uint k; k < collectionBribes[collection[i]].length;) {
                _claim(collectionBribes[collection[i]][k], account, epoch[i], collection[i], votes[i], merkleProof[i]);
                unchecked { ++k; }
            }

            // Mark our collection rewards for the epoch as claimed for the user
            userClaimed[userClaimHash] = true;

            unchecked { ++i; }
        }
    }

    function _claim(uint bribeId, address account, uint epoch, address collection, uint votes, bytes32[] calldata merkleProof) internal {
        // Verify our merkle proof
        require(MerkleProof.verify(
            merkleProof,
            epochMerkles[epoch],
            keccak256(abi.encode(account, epoch, collection, votes))
        ), 'Invalid Merkle Proof');

        // If the user is blacklisted from the bribe, then don't offer any reward
        if (isBlacklisted[bribeId][account]) {
            return;
        }

        // Load our bribe into memory as we won't be updating any content
        Bribe memory bribe = bribes[bribeId];

        // Determine the reward amount for the user
        // TODO: Need to consider less than max
        uint amount = votes * bribe.maxRewardPerVote;

        // Determine the amount of fee, if applicable, to return to the DAO for
        // facilitating the vote market.
        if (DAO_FEE != 0) {
            uint feeAmount = amount * DAO_FEE / 100;
            amount -= feeAmount;

            // Transfer fees to the DAO
            ERC20(bribe.rewardToken).transfer(feeCollector, feeAmount);
        }

        // Transfer to account claiming the reward
        ERC20(bribe.rewardToken).transfer(account, amount);

        // Emit our event
        emit Claimed(account, bribe.rewardToken, bribeId, amount, epoch);
    }

    function claimHash(address collection, uint epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(collection, epoch));
    }

    function hasUserClaimed(address collection, uint epoch) external view returns (bool) {
        return userClaimed[claimHash(collection, epoch)];
    }

    function registerClaims(uint epoch, bytes32 merkleRoot) external {
        // Ensure that only our oracle wallet can call this function
        require(msg.sender == oracleWallet, 'Unauthorized caller');

        // Ensure that a merkleRoot has not already been set to this epoch
        require(epochMerkles[epoch] == '', 'merkleRoot already set');

        // Register the merkleRoot against our epoch
        epochMerkles[epoch] = merkleRoot;

        // Emit our claim registration event
        emit ClaimRegistered(epoch, merkleRoot);
    }

    function setOracleWallet(address _oracleWallet) external onlyOwner {
        // We don't validate our oracle wallet address, we just assume the caller
        // isn't an idiot.
        oracleWallet = _oracleWallet;
    }

    function expireCollectionBribes(address[] calldata collection, uint[] calldata index) external {
        // Ensure that only our oracle wallet can call this function
        require(msg.sender == oracleWallet, 'Unauthorized caller');

        // Delete bribes based on the collection and index. This does not delete the
        // bribe structure, but instead just deletes the collection mapping so it is
        // no longner included in calculations or claims.
        //
        // @dev Warning: This does not sense check the information.
        for (uint i; i < collection.length;) {
            delete collectionBribes[collection[i]][index[i]];
            unchecked { ++i; }
        }
    }

}
