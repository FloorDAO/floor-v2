// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './BaseStrategy.sol';


/**
 * Supports an Liquidity Staking position against a single NFTX vault. This strategy
 * will hold the corresponding xSLP token against deposits.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 *
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
interface INFTXLiquidityStakingStrategy is IBaseStrategy {

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
     * Deposit underlying token or yield token to corresponding strategy. This function expects
     * that the SLP token will be deposited and will not facilitate double sided staking or
     * handle the native chain token to balance the sides.
     *
     * Requirements:
     *  - Caller should make sure the token is already transfered into the strategy contract.
     *  - Caller should make sure the deposit amount is greater than zero.
     *
     * - Get the vault ID from the underlying address (vault address)
     * - LiquidityStaking.deposit(uint256 vaultId, uint256 _amount)
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

}
