// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IBaseStrategy {

    /// @dev When strategy receives a deposit
    event Deposit(uint amount);

    /// @dev When strategy is harvested
    event Harvest(uint amount[]);

    /// @dev When a staked user exits their position
    event Exit(uint amount[]);

    /**
     * Return the the address of the yield token.
     */
    function yieldToken() external view returns (address[]);

    /**
     * Return the the address of the underlying token. This could be the same as
     * the yield token.
     */
    function underlyingToken() external view returns (address[]);

    /**
     * Deposit underlying token or yield token to corresponding strategy.
     *
     * Requirements:
     *  - Caller should make sure the token is already transfered into the strategy contract.
     *  - Caller should make sure the deposit amount is greater than zero.
     *
     * @param _amount The amount of token to deposit.
     *
     * @return _yieldAmount The amount of yield token deposited.
     */
    function deposit(uint256 _amount[]) external returns (uint256 _yieldAmount);

    /**
     * Harvest possible rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * @return _returnAmount The amount of yield token harvested.
     */
    function harvest() external returns (uint256 _returnAmount[]);

    /**
     * Allows a staked user to exit their strategy position, burning all corresponding
     * xToken to retrieve all their underlying tokens.
     *
     * @return _returnAmount The amount of underlying token claimed from exit.
     */
    function exit(address _recipient, uint256 _amount[]) external returns (uint256 _returnAmount[]);

    /**
     * Emergency function to execute arbitrary call.
     *
     * This function should be only used in case of emergency. It should never be called explicitly
     * in any contract in normal case, and should only be available to guardian or governor.
     *
     * @param _to The address of target contract to call.
     * @param _value The value passed to the target contract.
     * @param _data The calldata pseed to the target contract.
     */
    function execute(address _to, uint256 _value, bytes calldata _data) external payable returns (bool, bytes memory);

}
