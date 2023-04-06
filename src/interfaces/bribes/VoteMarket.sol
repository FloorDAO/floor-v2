// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVoteMarket {
    /// @notice Bribe struct requirements.
    struct Bribe {
        // ID of the bribe
        uint bribeId;
        // Address of the target gauge.
        address collection;
        // Address of the ERC20 used for rewards.
        address rewardToken;
        // The first epoch at which the bribe reward is claimable.
        uint startEpoch;
        // Number of periods.
        uint8 numberOfEpochs;
        // Max Price per vote.
        uint maxRewardPerVote;
        // Total Reward Added.
        uint totalRewardAmount;
        // Blacklisted addresses.
        address[] blacklist;
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
