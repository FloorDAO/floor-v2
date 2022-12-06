// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './BaseStrategy.sol';


/**
 * Supports an Inventory Staking position against a single NFTX vault. This strategy
 * will hold the corresponding xToken against deposits.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 *
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
interface INFTXInventoryStakingStrategy is IBaseStrategy {

    /**
     * Return the the address of the yield token.
     *
     * The reward yield will be a vault xToken as defined by the InventoryStaking contract.
     */
    function yieldToken() external view returns (address);

    /**
     * Return the the address of the underlying token.
     *
     * The underlying token will be the same as the address of the NFTX vault.
     */
    function underlyingToken() external view returns (address);

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
    function deposit(uint256 _amount) external returns (uint256 yieldAmount_);

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
    function claimRewards(uint amount) external returns (uint256 amount_);

    /**
     * Allows a staked user to exit their strategy position, burning all corresponding
     * xToken to retrieve all their underlying tokens.
     */
    function exit() external returns (uint256 returnAmount_);

}
