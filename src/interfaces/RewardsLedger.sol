// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * @dev The rewards ledger holds all available rewards available to be claimed
 * by FLOOR users, as well as keeping a simple ledger of all tokens already
 * claimed.
 *
 * The {RewardsLedger} will have the ability to transfer assets from {Treasury}
 * to recipient as it sees fit, whilst providing some separation of concerns.
 */

interface IRewardsLedger {

    /**
     * Stored as mapping[recipient] = RewardToken[];
     */
    struct RewardToken {
        address token;
        uint available;
        uint totalClaimed;
    }

    /// @dev Emitted when rewards are allocated to a user
    event RewardsAllocated(address recipient, address token, uint amount);

    /// @dev Emitted when rewards are claimed by a user
    event RewardsClaimed(address recipient, address token, uint amount);

    /// @dev Emitted when rewards claiming is paused or unpaused
    event RewardsPaused(bool paused);

    /**
     * Returns the address of the {Treasury} contract.
     */
    function treasury() external pure returns (address);

    /**
     * Allocated a set amount of a specific token to be accessible by the recipient. This
     * information will be stored in a {RewardToken}, either creating or updating the
     * struct.
     */
    function allocate(address recipient, address token, uint amount) external returns (uint available);

    /**
     * These tokens are stored in the {Treasury}, but will be allowed access from
     * this contract to allow them to be claimed at a later time.
     *
     * A user will be able to claim the token as long as the {Treasury} holds
     * the respective token (which it always should) and has sufficient balance
     * in `available`.
     */
    function claim(address token, uint amount) external returns (uint totalClaimed);

    /**
     * Allows our governance to pause rewards being claimed. This should be used
     * if an issue is found in the code causing incorrect rewards being distributed,
     * until a fix can be put in place.
     */
    function pause(bool pause) external;

}
