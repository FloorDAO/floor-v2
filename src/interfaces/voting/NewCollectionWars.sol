// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INewCollectionWars {
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

    /// Sent when a user casts a vote
    event VoteCast(address sender, address collection, uint userVotes, uint collectionVotes);

    /// Sent when a collection vote is revoked
    event VoteRevoked(address sender, address collection, uint collectionVotes);

    /// Sent when a collection NFT is staked to vote
    event NftVoteCast(address sender, uint war, address collection, uint collectionVotes, uint collectionNftVotes);

    /// Sent when a Collection Addition War is created
    event CollectionAdditionWarCreated(uint epoch, address[] collections, uint[] floorPrices);

    /// Sent when a Collection Addition War is started
    event CollectionAdditionWarStarted(uint warIndex);

    /// Sent when a Collection Addition War ends
    event CollectionAdditionWarEnded(uint warIndex);

    /// Sent when Collection Addition War NFTs are exercised
    event CollectionExercised(uint warIndex, address collection, uint value);

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

    /// Stores the address of the collection that won a Floor War
    function floorWarWinner(uint _epoch) external view returns (address);

    /// Stores if a collection has been flagged as ERC1155
    function is1155(address) external returns (bool);

    /// Stores the unlock epoch of a collection in a floor war
    function collectionEpochLock(bytes32) external returns (uint);

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
     * Allows an approved contract to submit option-related votes against a collection
     * in the current war.
     *
     * @param sender The address of the user that staked the token
     * @param collection The collection to cast the vote against
     * @param votingPower The voting power added from the option creation
     */
    function optionVote(address sender, uint war, address collection, uint votingPower) external;

    /**
     * Revokes a user's current votes in the current war.
     *
     * @dev This is used when a user unstakes their floor
     *
     * @param account The address of the account that is having their vote revoked
     */
    function revokeVotes(address account) external;

    /**
     * Allow an authorised user to create a new floor war to start with a range of
     * collections from a specific epoch.
     */
    function createFloorWar(uint epoch, address[] calldata collections, bool[] calldata isErc1155, uint[] calldata floorPrices)
        external
        returns (uint);

    /**
     * Sets a scheduled {FloorWar} to be active.
     *
     * @dev This function is called by the {EpochManager} when a new epoch starts
     *
     * @param index The index of the {FloorWar} being started
     */
    function startFloorWar(uint index) external;

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
     * Allows us to update our collection floor prices if we have seen a noticable difference
     * since the start of the epoch. This will need to be called for this reason as the floor
     * price of the collection heavily determines the amount of voting power awarded when
     * creating an option.
     */
    function updateCollectionFloorPrice(address collection, uint floorPrice) external;

    /**
     * Allows our options contract to be updated.
     *
     * @param _contract The new contract to use
     */
    function setOptionsContract(address _contract) external;

    /**
     * Check if a collection is in a FloorWar.
     */
    function isCollectionInWar(bytes32 warCollection) external view returns (bool);
}
