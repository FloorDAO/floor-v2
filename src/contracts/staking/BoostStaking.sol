// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {IBoostStaking} from '../../interfaces/staking/BoostStaking.sol';


/**
 * Partial interface for the Sweeper NFT data store.
 */
interface ISweeperMetadataStore {
    function boostValue(uint) external returns (uint8);
}


/**
 * This contract allows a specified NFT to be depoited into it to generate additional
 * vote reward boosting. When designing this we wanted to keep the reward gain non-linear,
 * so that it wasn't about hoarding NFTs but instead about pooling a small number of
 * higher boost value NFTs together.
 *
 * To achieve this, we use a formula that effectively increases the degredation based on
 * a numerical index against the total number of staked NFTs:
 *
 * ```
 * 10% + 5% + 5% = (10 / sqrt(1)) + (5 / sqrt(2)) + (5 / sqrt(3)) = 16.422
 * 10% + 10% = (10 / sqrt(1)) + (10 / sqrt(2))
 * ```
 *
 * We prioritise higher level boost values, so after a number of staked items come in,
 * gains will be negligible.
 */

contract BoostStaking is IBoostStaking, Pausable {

    /// Representation of rarity boost values to 1 decimal accuracy
    uint8[4] internal RARITIES = [/* COMMON */ 10, /* UNCOMMON */ 25, /* RARE */ 50, /* LEGENDARY */ 100 ];

    /// Returns the address of the user that has staked the specified `tokenId`.
    mapping (uint => address) public tokenStaked;

    /// Gets the number tokens that a user has staked at each boost value.
    mapping (address => mapping(uint8 => uint16)) public userTokens;

    /// The boost value applied to the user.
    mapping (address => uint) public boosts;

    /// NFT contract address.
    address public immutable nft;

    /// The external NFT meta data store contract
    ISweeperMetadataStore public immutable tokenStore;

    /**
     * Sets up our immutable contract addresses.
     */
    constructor (address _nft, address _tokenStore) {
        nft = _nft;
        tokenStore = ISweeperMetadataStore(_tokenStore);
    }

    /**
     * Stakes an approved NFT into the contract and provides a boost based on the relevant
     * metadata on the NFT.
     *
     * @dev This can only be called when the contract is not paused.
     *
     * @param _tokenId Token ID to be staked
     */
    function stake(uint _tokenId) external updateRewards whenNotPaused {
        // Mark the tokenId as staked against the user
        tokenStaked[_tokenId] = msg.sender;

        // Captures the NFT boost against the user
        userTokens[msg.sender][tokenStore.boostValue(_tokenId)] += 1;

        // Transfer the ERC721 from the user to this staking contract
        IERC721(nft).safeTransferFrom(msg.sender, address(this), _tokenId, bytes(''));
        emit Staked(_tokenId);
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param _tokenId Token ID to be staked
     */
    function unstake(uint _tokenId) external updateRewards {
        // Ensure the user is the owner of the staked ERC721
        require(tokenStaked[_tokenId] != msg.sender, 'Not owner');

        // Unassign the token from the user
        delete tokenStaked[_tokenId];

        // Captures the NFT boost against the user
        userTokens[msg.sender][tokenStore.boostValue(_tokenId)] -= 1;

        // Transfer the ERC721 back to the user
        IERC721(nft).safeTransferFrom(address(this), msg.sender, _tokenId, bytes(''));
        emit Unstaked(_tokenId);
    }

    /**
     * After a transaction is run, this logic will recalculate the user's boosted balance based
     * on an a degrading curve outlined at the top of this contract.
     */
    modifier updateRewards() {
        _;

        uint newBoost;
        uint count = 1;

        // Check all rarities against the user, starting with the biggest rewards and
        // then iterating to smaller values.
        for (uint i; i < RARITIES.length;) {
            // For each token of that rarity, we add a decreasing penalty to prevent
            // mass holdings providing massive reward increase.
            for (uint j = userTokens[msg.sender][RARITIES[i]]; j != 0;) {
                newBoost += (RARITIES[i] / Math.sqrt(count));
                unchecked { --j; ++count; }
            }
            unchecked { ++i; }
        }

        // Set our user's boost
        boosts[msg.sender] = newBoost;
    }

}
