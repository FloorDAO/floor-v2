// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';


/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting.
 */

contract BoostStaking is Pausable {

    struct StakedToken {
        uint tokenId;
        uint value;
        uint epoch;
        uint epochCount;
    }

    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;

    /// Gets the number of tokens that a user has staked for each collection.
    mapping(address => mapping(address => StakedToken[])) internal stakedTokens;

    /// Stores the boosted number of votes available to a user
    mapping(address => uint) userBoost;

    /// Store the amount of discount applied to voting power of staked NFT
    uint public voteDiscount;

    /**
     * Sets up our immutable contract addresses.
     */
    constructor(uint _voteDiscount) {
        voteDiscount = _voteDiscount;
    }

    /**
     * Stakes an approved collection NFT into the contract and provides a boost based on
     * the price of the underlying ERC20.
     *
     * @dev This can only be called when the contract is not paused.
     *
     * @param _collection Approved collection contract
     * @param _tokenId Token ID to be staked
     */
    function stake(address _collection, uint _tokenId, uint epochCount) external updateRewards whenNotPaused {
        // Ensure we have a mapped underlying token
        require(underlyingTokenMapping[_collection] != address(0), 'Underlying token not found');

        // Add staked token mapping
        unchecked { stakedTokens[msg.sender][_collection] += 1; }

        // Transfer the token into the contract
        IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId, bytes(''));

        // Find the current value of the token
        uint tokenValue;

        // Grant the user a vote boost based on the value of the token
        unchecked {
            userBoost[msg.sender] += tokenValue;
        }

        // Stake the token into NFTX vault


        // Store the token against our user
        stakedTokens[msg.sender][_collection].push(
            StakedToken(
                _tokenId,
                tokenValue,
                currentEpoch,
                epochCount,
            )
        );

        // ..
        emit Staked(_tokenId);
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param _tokenId Token ID to be staked
     */
    function unstake(address _collection, bool _emergencyExit) external {
        // We need to store the number of NFTs to mint, as well as any token dust that
        // will need to be sent to the user as ERC20s. Dust should only occur if the
        // user has opted to emergency exit.
        uint tokenDust;
        uint tokenMints;

        // Loop through all staked tokens for the collection
        uint iterations = stakedTokens[msg.sender][_collection];
        for (uint i; i < iterations;) {
            // Find our maturity percentage
            uint maturityPercentage = 10000;
            if (currentEpoch > stakedTokens[msg.sender][_collection].epoch + stakedTokens[msg.sender][_collection].epochCount) {
                if (currentEpoch == stakedTokens[msg.sender][_collection].epoch) {
                    maturityPercentage = 0;
                }
                else {
                    maturityPercentage = 10000 / (stakedTokens[msg.sender][_collection].epochCount / (currentEpoch - stakedTokens[msg.sender][_collection].epoch));
                }
            }

            // Check if our staked token has matured to determine the format that the
            // token is returned to the user.
            if (maturityPercentage != 10000) {
                // If we are not emergency exiting, then we need to skip any staked tokens
                // that haven't fully matured.
                if (!_emergencyExit) {
                    continue;
                }

                unchecked {
                    tokenDust += (1 ether * maturityPercentage) / 10000;
                }
            }
            else {
                unchecked { tokenMints += 1; }
            }

            // Remove the boosted value of the staked NFT against the user
            unchecked {
                userBoost[msg.sender] -= stakedTokens[msg.sender][_collection][i].amount;
            }

            // Delete the stored token struct
            delete stakedTokens[msg.sender][_collection][i];

            unchecked { ++i; }
        }

        // Random redeem an NFT from the collection via NFTX and send to user


        // Get ERC20 dust


        // Emit event
        // ..
    }

    function setVoteDiscount(uint _voteDiscount) external onlyOwner {
        voteDiscount = _voteDiscount;
    }

}
