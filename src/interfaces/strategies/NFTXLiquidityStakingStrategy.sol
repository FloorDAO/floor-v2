// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
interface INFTXLiquidityStakingStrategy {

    /**
     * Return the the address of the yield token.
     *
     * The reward yield token will be the token defined in the {LiquidityStaking} contract.
     */
    function yieldToken() external view returns (address[] calldata);

    /**
     * Return the the address of the underlying token.
     *
     * The underlying token will be a liquidity SLP as defined by the {LiquidityStaking} contract.
     */
    function underlyingToken() external view returns (address[] calldata);

    /**
     * Deposit underlying token or yield token to corresponding strategy.
     *
     * Requirements:
     *  - Caller should make sure the token is already transfered into the strategy contract.
     *  - Caller should make sure the deposit amount is greater than zero.
     *
     * - Get the vault ID from the underlying address (vault address)
     * - InventoryStaking.deposit(uint256 vaultId, uint256 _amount)
     *   - This deposit will be timelocked
     *   - If the pool currently has no liquidity, it will additionally
     *     initialise the pool
     * - We receive xSLP back to the strategy
     */
    function deposit(address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata yieldAmount_);

    /**
     * Harvest possible rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * - Get the vaultID from the underlying address
     * - LiquidityStaking.receiveRewards
     * - Distribute yield
     */
    function harvest() external returns (address[] calldata token_, uint256[] calldata returnAmount_);

    /**
     * Allows a staked user to exit their strategy position, burning all corresponding
     * xSLP to retrieve all their underlying tokens.
     */
    function exit(address _recipient, address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata returnAmount_);

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
