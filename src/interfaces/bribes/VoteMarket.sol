// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVoteMarket {

    /**
     * Bribe struct requirements.
     *
     * @param bribeId ID of the bribe
     * @param startEpoch The first epoch at which the bribe reward is claimable.
     * @param maxRewardPerVote Max Price per vote.
     * @param totalRewardAmount The total amount of `rewardToken` funding the bribe.
     * @param remainingRewards Tracking of the number of rewards remaining.
     * @param collection Address of the target gauge.
     * @param rewardToken Address of the ERC20 used for rewards.
     * @param creator The creator of the bribe.
     * @param numberOfEpochs The number of epochs the bribe will run for.
     */
    struct Bribe {
        uint startEpoch;         // 256 / 256
        uint maxRewardPerVote;   // 512 / 512
        uint remainingRewards;   // 768 / 768
        uint totalRewardAmount;  // 1024 / 1024
        address collection;      // 1184 / 1280
        address rewardToken;     // 1344 / 1536
        address creator;         // 1504 / 1536
        uint8 numberOfEpochs;    // 1512 / 1536
    }

    /// Fired when a new bribe is created
    event BribeCreated(uint bribeId);

    /// Fired when a user claims their bribe allocation
    event Claimed(address account, address rewardToken, uint bribeId, uint amount, uint epoch);

    /// Fired when a new claim allocation is assigned for an epoch
    event ClaimRegistered(uint epoch, bytes32 merkleRoot);

    /// Minimum number of epochs for a Bribe
    function MINIMUM_EPOCHS() external returns (uint8);

    /// The percentage of bribes that will be sent to the DAO
    function DAO_FEE() external returns (uint8);

    /// The recipient of any fees collected. This should be set to the {Treasury}, or
    /// to a specialist fee collection contract.
    function feeCollector() external returns (address);

    /// Store our claim merkles that define the available rewards for each user across
    /// all collections and bribes.
    // function epochMerkles(uint epoch) external returns (bytes32);

    /// Stores a list of all bribes created, across past, live and future
    // function bribes(uint index) external returns (Bribe memory);

    /// A mapping of collection addresses to an array of bribe array indexes
    // function collectionBribes(address) external returns (uint[] memory);

    /// Blacklisted addresses per bribe that aren't counted for rewards arithmetics.
    function isBlacklisted(uint bribeId, address account) external returns (bool);

    /// Oracle wallet that has permission to write merkles
    function oracleWallet() external returns (address);

    /**
     * Create a new bribe.
     *
     * @param collection Address of the target collection.
     * @param rewardToken Address of the ERC20 used or rewards.
     * @param startEpoch The epoch to start offering the bribe.
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
        uint startEpoch,
        uint8 numberOfEpochs,
        uint maxRewardPerVote,
        uint totalRewardAmount,
        address[] calldata blacklist
    ) external returns (uint newBribeID);

    function claim(
        address account,
        uint[] calldata epoch,
        uint[] calldata bribeIds,
        address[] calldata collection,
        uint[] calldata votes,
        bytes32[][] calldata merkleProof
    ) external;

    function claimAll(
        address account,
        uint[] calldata epoch,
        address[] calldata collection,
        uint[] calldata votes,
        bytes32[][] calldata merkleProof
    ) external;

    function hasUserClaimed(uint bribeId, uint epoch) external view returns (bool);

    function registerClaims(uint epoch, bytes32 merkleRoot, address[] calldata collections, uint[] calldata collectionVotes) external;

    function setOracleWallet(address _oracleWallet) external;

    function extendBribes(uint epoch) external;

    function expireCollectionBribes(address[] calldata collection, uint[] calldata index) external;
}
