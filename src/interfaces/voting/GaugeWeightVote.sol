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

    /// Sent when voting is paused or unpaused
    event VotingPaused(bool paused);

    /// Sent when a user casts or revokes their vote
    event VoteCast(uint vaultId, uint amount);

    /// Sent when a snapshot is generated
    event SnapshotCreated(address[] vault, uint[] percentage);

    /**
     * Mapping vault address -> voter address -> amount.
     *
     * We will need to maintain an internal structure to map the voters against
     * a vault address, so that we can iterate over it to find total vote counts.
     */

    /**
     * The total voting power of a user, regardless of if they have cast votes
     * or not.
     */
    function userVotingPower(address _user) external view returns (uint);

    /**
     * A collection of votes that the user currently has placed.
     */
    function userVotes(address _user) external view returns (address[] memory vault_, uint[] memory votes_);

    /**
     * The total number of votes that a user has available, calculated by:
     *
     * ```
     * votesAvailable_ = balanceOf(_user) - SUM(userVotes.votes_)
     * ```
     */
    function userVotesAvailable(address _user) external view returns (uint votesAvailable_);

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
    function vote(uint _vaultId, uint _amount) external returns (uint totalVotes_);

    /**
     * Allows a user to revoke their votes from vaults. This will free up the
     * user's available votes that can subsequently be voted again with.
     */
    function revokeVote(uint[] memory _vaultId, uint[] memory _amount) external returns (uint[] memory remainingVotes_);

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
    function snapshot() external returns (address[] memory vault_, uint[] memory percentage_);

    /**
     * Allows voting to be paused or unpaused on the contract.
     */
    function pauseVoting(bool paused) external;

}
