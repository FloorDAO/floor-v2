// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
interface INFTXInventoryStakingStrategy {

    /**
     * Return the the address of the yield token.
     *
     * The reward yield will be a vault xToken as defined by the InventoryStaking contract.
     */
    function yieldToken() external view returns (address[] calldata);

    /**
     * Return the the address of the underlying token.
     *
     * The underlying token will be the same as the address of the NFTX vault.
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
     * - We receive xToken back to the strategy
     */
    function deposit(address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata yieldAmount_);

    /**
     * Harvest possible rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * - Get the vaultID from the underlying address
     * - Calculate the additional xToken held, above the staking token
     * - InventoryStaking.withdraw the difference to get the reward
     * - Distribute yield
     */
    function harvest() external returns (address[] calldata token_, uint256[] calldata returnAmount_);

    /**
     * Allows a staked user to exit their strategy position, burning all corresponding
     * xToken to retrieve all their underlying tokens.
     */
    function exit(address _recipient, address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata returnAmount_);

}
