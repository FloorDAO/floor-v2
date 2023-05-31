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
    event Deposit(address token, uint amount, address caller);

    /// @dev When strategy is harvested
    event Harvest(address token, uint amount);

    /// @dev When a staked user exits their position
    event Withdraw(address token, uint amount, address caller);

    /**
     * Allows the vault to be initialised.
     */
    function initialize(bytes32 name, uint strategyId, bytes calldata initData) external;

    /**
     * Name of the strategy.
     */
    function name() external view returns (bytes32);

    /**
     * The numerical ID of the vault that acts as an index for the {StrategyFactory}.
     */
    function strategyId() external view returns (uint);

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     */
    function lifetimeRewards(address token) external returns (uint amount_);

    /**
     * The amount of rewards claimed in the last claim call.
     */
    function lastEpochRewards(address token) external returns (uint amount_);

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external returns (address[] memory, uint[] memory);

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action.
     *
     * @dev This _should_ always be imposed to be the {Treasury} by the {StrategyFactory}.
     */
    function harvest(address /* _recipient */ ) external;

    /**
     * Returns an array of tokens that the strategy supports.
     *
     * @return address[] The address of valid tokens
     */
    function validTokens() external view returns (address[] memory);

    /**
     * Pauses deposits from being made into the vault. This should only be called by
     * a guardian or governor.
     *
     * @param _p Boolean value for if the vault should be paused
     */
    function pause(bool _p) external;

    /**
     * ..
     */
    function snapshot() external returns (address[] memory, uint[] memory);
}
