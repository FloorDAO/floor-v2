// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Strategies will hold the logic for interacting with external platforms to stake
 * and harvest reward yield. Each vault will require its own strategy implementation
 * to allow for different immutable variables to be defined during construct.
 *
 * This will follow a similar approach to how NFTX offer their eligibility module
 * logic, with a lot of the power coming from inheritence.
 *
 * When constructed, we want to give the {Treasury} a max uint approval of the yield
 * and underlying tokens.
 */
interface IBaseStrategy {

    /// @dev When strategy receives a deposit
    event Deposit(address token, uint amount);

    /// @dev When strategy is harvested
    event Harvest(address token, uint amount);

    /// @dev When a staked user exits their position
    event Exit(address token, uint amount);

    /**
     * Allows the vault to be initialised.
     */
    function initialize(uint _vaultId, bytes memory initData) external;

    /**
     * Name of the strategy.
     */
    function name() external view returns (bytes32);

    /**
     * The amount of reward tokens generated by the strategy that is allocated to, but has not
     * yet been, minted into FLOOR tokens. This will be calculated by a combination of an
     * internally incremented tally of claimed rewards, as well as the returned value of
     * `rewardsAvailable` to determine pending rewards.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function unmintedRewards() external returns (uint amount_);

    /**
     * This will return the internally tracked value of tokens that have been minted into
     * FLOOR by the {Treasury}.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function mintedRewards() external returns (uint amount_);

    /**
     * The token amount of reward yield available to be claimed on the connected external
     * platform. Our `claimRewards` function will always extract the maximum yield, so this
     * could essentially return a boolean. However, I think it provides a nicer UX to
     * provide a proper amount and we can determine if it's financially beneficial to claim.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function rewardsAvailable() external returns (uint amount_);

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function totalRewardsGenerated() external returns (uint amount_);

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     */
    function registerMint(uint amount) external;

}
