// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * veFloorStaking will act as a pool, allowing users to stake their FLOOR to receive
 * veFLOOR. This allocation will allow for increased claimable veFLOOR over a defined
 * time period, with more available as a longer duration is staked for.
 *
 * veFLOOR cannot be transferred, only minted or burnt. When either of these actions are
 * undertaken the users staking information will be updated through the ERC20
 * `_afterTokenOperation` call.
 *
 * To incentivize the holding of FLOOR tokens, those who “lock” for longer time periods
 * benefit from:
 *
 *  - Increased voting power
 *  - Locked FLOOR holders receive yield from the veFLOOR gauge
 *
 * https://snowtrace.io/address/0x1bf56b7c132b5cc920236ae629c8a93d9e7831e7#code
 */
interface IVoteStaking {

    /**
     * Sent when a user claims veFloor.
     */
    event Claim(address indexed user, uint256 amount);

    /**
     * Sent when the user stakes Floor for veFloor.
     */
    event Staked(address indexed user, uint256 amount);

    /**
     * Sent when the user unstakes veFloor to Floor.
     */
    event Unstaked(address indexed user, uint256 withdrawAmount, uint256 burnAmount);

    /**
     * The following events are sent when then owner updates any of the reward
     * variables that determine the veFloor curve.
     */
    event UpdateMaxCapPct(address indexed user, uint256 maxCapPct);
    event UpdateSpeedUpThreshold(address indexed user, uint256 speedUpThreshold);
    event UpdateVeFloorPerSharePerSec(address indexed user, uint256 veFloorPerSharePerSec);

    /**
     * Sent when the reward variables are updated.
     */
    event UpdateRewardVars(uint256 lastRewardTimestamp, uint256 accVeFloorPerShare);

    /**
     * Deposits Floor to start staking for veFloor. Note that any pending veFloor
     * should also be claimed in the process.
     */
    function stake(uint _amount) external returns (uint);

    /**
     * Withdraw staked Floor. Unstaking any amount of Floor means that the account
     * will lose all current veFloor.
     */
    function unstake(uint _amount) external returns (uint);

    /**
     * Claim any pending veFloor for the user.
     */
    function claim(address _user) external;

    /**
     * Get the pending amount of veFloor for a given user.
     */
    function claimAvailable(address _user) external returns (uint);

    /**
     * Update global reward variables to calculate the accumulated veFloor per share.
     */
    function updateRewardVars() public;

    /* --- */

    /**
     * Sets the max cap percentage; used to determine veFloor gain.
     *
     * The maximum limit of veFloor user can have as percentage points of staked
     * Floor. For example, if user has `n` Floor staked, they can own a maximum of
     * `n * maxCapPct / 100` veFloor.
     */
    function setMaxCapPct(uint _maxCapPct) external;

    /**
     * Sets the veFloor per share, per second; used to determine veFloor gain.
     */
    function setVeFloorPerSharePerSec(uint _veJoePerSharePerSec) external;

    /**
     * Sets the speed up threshold that determines the share curve; used to determine
     * veFloor gain. The length of time a user receives speed up benefits.
     *
     * Percentage of user's current staked Floor user has to deposit in order to start
     * receiving speed up benefits, in parts per 100.
     *
     * Specifically, user has to deposit at least `speedUpThreshold/100 * userStakedJoe`
     * FLOOR. The only exception is the user will also receive speed up benefits if they
     * are depositing with zero balance.
     */
    function setSpeedUpThreshold(uint _speedUpThreshold) external;

}
