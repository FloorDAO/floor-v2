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
 */
interface IVoteStaking {

    /**
     * Wraps our users Floor into veFloor.
     */
    function stake(address _to, uint256 _amount) external returns (uint256);

    /**
     * Unwraps a users veFloor to Floor.
     */
    function unstake(address _to, uint256 _amount) external returns (uint256);

}
