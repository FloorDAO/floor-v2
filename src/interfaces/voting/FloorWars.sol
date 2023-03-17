// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFloorWars {

    /**
     * Stores information about the NFT that has been staked. This allows either
     * the DAO to exercise the NFT, or for the initial staker to reclaim it.
     */
    struct StakedCollectionERC721 {
        address staker;          // 160 / 256
        uint56 exercisePercent;  // 216 / 256
    }

    /**
     * ..
     */
    struct StakedCollectionERC1155 {
        address staker;          // 160 / 256
        uint56 exercisePercent;  // 216 / 256
        uint40 amount;           // 256 / 256
    }

    /**
     * For each FloorWar that is created, this structure will be created. When
     * the epoch ends, the FloorWar will remain and will be updated with information
     * on the winning collection and the votes attributed to each collection.
     */
    struct FloorWar {
        uint index;
        uint startEpoch;
        address[] collections;
    }

    /**
     * Stores the current epoch enforced by the {Treasury}.
     */
    function currentEpoch() external view returns (uint);

    /// Stores the number of votes a user has placed against a war collection
    function userVotes(bytes32) external view returns (uint);

    /// Stores the floor spot price of a collection token against a war collection
    function collectionSpotPrice(bytes32) external view returns (uint);

    /// Stores the total number of votes against a war collection
    function collectionVotes(bytes32) external view returns (uint);
    function collectionNftVotes(bytes32) external view returns (uint);

    /// Stores which collection the user has cast their votes towards to allow for
    /// reallocation on subsequent votes if needed.
    function userCollectionVote(bytes32) external view returns (address);

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     *
     * @param _user User address being checked
     */
    function userVotingPower(address _user) external view returns (uint);

    /**
     * The total number of votes that a user has available.
     *
     * @param _user User address being checked
     *
     * @return uint Number of votes available to the user
     */
    function userVotesAvailable(uint _war, address _user) external view returns (uint);

    /**
     * Allows the user to cast 100% of their voting power against an individual
     * collection. If the user has already voted on the FloorWar then this will
     * additionally reallocate their votes.
     */
    function vote(address collection) external;

    /**
     * ..
     *
     * TODO: Lock down to vote manager
     */
    function revokeVotes(address account) external;

    /**
     * Allows the user to deposit their ERC721 or ERC1155 into the contract and
     * gain additional voting power based on the floor price attached to the
     * collection in the FloorWar.
     */
    function voteWithCollectionNft(address collection, uint[] calldata tokenIds, uint40[] calldata amounts, uint56[] calldata exercisePercent) external;

    /**
     * Allow an authorised user to create a new floor war to start with a range of
     * collections from a specific epoch.
     */
    function createFloorWar(uint epoch, address[] calldata collections, bool[] calldata isErc1155, uint[] calldata floorPrices) external returns (uint);

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
    function endFloorWar() external returns (address highestVoteCollection);

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseCollectionERC721s(uint war, uint[] calldata tokenIds) external payable;

    /**
     * Allows an approved user to exercise the staked NFT at the price that it was
     * listed at by the staking user.
     */
    function exerciseCollectionERC1155s(uint war, uint[] calldata tokenIds, uint[] memory amount) external payable;

    /**
     * If the FloorWar has not yet ended, or the NFT timelock has expired, then the
     * user reclaim the staked NFT and return it to their wallet.
     *
     *  start    current
     *  0        0         < locked
     *  0        1         < locked if won
     *  0        2         < free
     */
    function reclaimCollectionNft(uint war, address collection, uint[] calldata tokenIds) external;

    /**
     * Determines the voting power given by a staked NFT based on the requested
     * exercise price and the spot price.
     */
    function nftVotingPower(uint spotPrice, uint exercisePercent) external view returns (uint);

    /**
     * Allows our epoch to be set by the {Treasury}. This should be sent when our {Treasury} ends
     * the current epoch and moves to a new one.
     *
     * @param _currentEpoch The new, current epoch
     */
    function setCurrentEpoch(uint _currentEpoch) external;

    /**
     * ..
     */
    function updateCollectionFloorPrice(address collection, uint floorPrice) external;
}
