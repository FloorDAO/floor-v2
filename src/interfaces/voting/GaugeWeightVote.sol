// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * The GWV will allow users to assign their veFloor position to a vault, or
 * optionally case it to a veFloor, which will use a constant value. As the
 * vaults will be rendered as an address, the veFloor vote will take a NULL
 * address value.
 *
 * At point of development this can take influence from:
 * https://github.com/saddle-finance/saddle-contract/blob/master/contracts/tokenomics/gauges/GaugeController.vy
 */
interface IGaugeWeightVote {
    /// Sent when a user casts or revokes their vote
    event VoteCast(address collection, uint amount);

    /// Sent when a snapshot is generated
    event SnapshotCreated(address[] vault, uint[] tokens);

    /**
     * ..
     */
    function votes(address) external view returns (uint);
    function votes(address, uint) external view returns (uint);

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     */
    function userVotingPower(address _user) external view returns (uint);

    /**
     * The total number of votes that a user has available, calculated by:
     *
     * ```
     * votesAvailable_ = balanceOf(_user) - SUM(userVotes.votes_)
     * ```
     */
    function userVotesAvailable(address _user) external view returns (uint votesAvailable_);

    /**
     * Provides a list of collection addresses that can be voted on.
     */
    function voteOptions() external view returns (address[] memory collections_);

    /**
     * Allows a user to cast a vote using their veFloor allocation. We don't
     * need to monitor transfers as veFloor can only be minted or burned, and
     * we check the voters balance during the `snapshot` call.
     *
     * A user can vote with a partial amount of their veFloor holdings, and when
     * it comes to calculating their voting power this will need to be taken into
     * consideration that it will be:
     *
     * ```
     * staked balance + (gains from staking * (total balance - staked balance)%)
     * ```
     *
     * The {Treasury} cannot vote with it's holdings, as it shouldn't be holding
     * any staked Floor.
     */
    function vote(address _collection, uint _amount) external;

    /**
     * Allows a user to revoke their votes from vaults. This will free up the
     * user's available votes that can subsequently be voted again with.
     */
    function revokeVotes(address[] memory _collection, uint[] memory _amount) external;

    /**
     * Allows an authorised contract or wallet to revoke all user votes. This
     * can be called when the veFLOOR balance is reduced.
     */
    function revokeAllUserVotes(address _account) external;

    /**
     * The snapshot function will need to iterate over all vaults that have
     * more than 0 votes against them. With that we will need to find each
     * vault's percentage share in relation to other vaults.
     *
     * This percentage share will instruct the {Treasury} on how much additional
     * FLOOR to allocate to the users staked in the vaults. These rewards will
     * become available in the {RewardLedger}.
     *
     * +----------------+-----------------+-------------------+-------------------+
     * | Voter          | veFloor         | Vote Weight       | Vault             |
     * +----------------+-----------------+-------------------+-------------------+
     * | Alice          | 30              | 40                | 1                 |
     * | Bob            | 20              | 30                | 2                 |
     * | Carol          | 40              | 55                | 3                 |
     * | Dave           | 20              | 40                | 2                 |
     * | Emily          | 25              | 35                | 0                 |
     * +----------------+-----------------+-------------------+-------------------+
     *
     * With the above information, and assuming that the {Treasury} has allocated
     * 1000 FLOOR tokens to be additionally distributed in this snapshot, we would
     * have the following allocations going to the vaults.
     *
     * +----------------+-----------------+-------------------+-------------------+
     * | Vault          | Votes Total     | Vote Percent      | veFloor Rewards   |
     * +----------------+-----------------+-------------------+-------------------+
     * | 0 (veFloor)    | 35              | 17.5%             | 175               |
     * | 1              | 40              | 20%               | 200               |
     * | 2              | 70              | 35%               | 350               |
     * | 3              | 55              | 27.5%             | 275               |
     * | 4              | 0               | 0%                | 0                 |
     * +----------------+-----------------+-------------------+-------------------+
     *
     * This would distribute the vaults allocated rewards against the staked
     * percentage in the vault. Any Treasury holdings that would be given in rewards
     * are just deposited into the {Treasury} as FLOOR, bypassing the {RewardsLedger}.
     */
    function snapshot(uint tokens, uint epoch) external returns (address[] memory collections);

    function addCollection(address _collection) external;
}
