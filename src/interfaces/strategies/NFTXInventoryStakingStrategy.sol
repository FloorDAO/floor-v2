// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
interface INFTXInventoryStakingStrategy is IBaseStrategy {

    /**
     * Return the the address of the yield token.
     *
     * The reward yield will be a vault xToken as defined by the InventoryStaking contract.
     */
    function yieldToken() external view returns (address[]);

    /**
     * Return the the address of the underlying token.
     *
     * The underlying token will be the same as the address of the NFTX vault.
     */
    function underlyingToken() external view returns (address[]);

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
     * - We receive xToken back to the strategy
     *
     * @param _amount The amount of token to deposit.
     *
     * @return _yieldAmount The amount of yield token deposited.
     */
    function deposit(uint256 _amount[]) external returns (uint256 _yieldAmount[]);

    /**
     * Harvest possible rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * - Get the vaultID from the underlying address
     * - Calculate the additional xToken held, above the staking token
     * - InventoryStaking.withdraw the difference to get the reward
     * - Distribute yield
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
