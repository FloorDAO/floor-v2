// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount} from '../utils/Errors.sol';

import {INFTXLiquidityStaking} from '../../interfaces/nftx/NFTXLiquidityStaking.sol';
import {ITimelockRewardDistributionToken} from '../../interfaces/nftx/TimelockRewardDistributionToken.sol';
import {IBaseStrategy} from '../../interfaces/strategies/BaseStrategy.sol';

/// If the contract was unable to transfer tokens when registering the mint
/// @param recipient The recipient of the token transfer
/// @param amount The amount requested to be transferred
error UnableToTransferTokens(address recipient, uint amount);

/// If a caller of a protected function is not the parent vault
/// @param sender The address making the call
error SenderIsNotVault(address sender);

/**
 * Supports an Liquidity Staking position against a single NFTX vault. This strategy
 * holds the corresponding xSLP token against deposits.
 *
 * The contract extends the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 *
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
contract NFTXLiquidityStakingStrategy is IBaseStrategy, Initializable {
    /// The human-readable name of the inventory strategy
    bytes32 public name;

    /// The vault ID that the strategy is attached to
    uint public vaultId;

    /// The address of the vault the strategy is attached to
    address public vaultAddr;

    // The address of the NFTX liquidity pool
    address public pool;

    /// The underlying token will be a liquidity SLP as defined by the {LiquidityStaking} contract.
    address public underlyingToken; // SLP

    /// The reward yield token will be the token defined in the {LiquidityStaking} contract.
    address public yieldToken; // xSLP

    /// Address of the NFTX Liquidity Staking contract
    address public liquidityStaking;

    /**
     * This will return the internally tracked value of tokens that have been minted into
     * FLOOR by the {Treasury}.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint public mintedRewards;

    /**
     * This will return the internally tracked value of tokens that have been claimed by
     * the strategy, regardless of if they have been minted into FLOOR.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint private lifetimeRewards;

    /**
     * This will return the internally tracked value of all deposits made into the strategy.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint public deposits;

    /**
     * Sets our strategy name.
     *
     * @param _name Human-readable name of the strategy
     */
    constructor(bytes32 _name) {
        name = _name;
    }

    /**
     * Sets up our contract variables.
     *
     * @param _vaultId Numeric ID of vault the strategy is attached to
     * @param _vaultAddr Address of vault the strategy is attached to
     * @param initData Encoded data to be decoded
     */
    function initialize(uint _vaultId, address _vaultAddr, bytes memory initData) public initializer {
        (
            address _pool,
            address _underlyingToken,
            address _yieldToken,
            address _liquidityStaking
        ) = abi.decode(initData, (address, address, address, address));

        pool = _pool;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        vaultId = _vaultId;
        vaultAddr = _vaultAddr;

        liquidityStaking = _liquidityStaking;

        IERC20(underlyingToken).approve(_liquidityStaking, type(uint).max);
    }

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
     *
     * @param amount Amount of underlying token to deposit
     *
     * @return xTokensReceived Amount of yield token returned from NFTX
     */
    function deposit(uint amount) external onlyVault returns (uint xTokensReceived) {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Get the SLP token from the user
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);

        // Get our xSLP starting balance
        uint startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));

        // Stake our SLP to get xSLP back
        INFTXLiquidityStaking(liquidityStaking).deposit(vaultId, amount);

        // Calculate how much xSLP was returned
        xTokensReceived = IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;
        deposits += xTokensReceived;

        emit Deposit(underlyingToken, amount, msg.sender);
    }

    /**
     * Allows the user to burn xToken to receive back their original token.
     *
     * @param amount Amount of yield token to withdraw
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdraw(uint amount) external onlyVault returns (uint amount_) {
        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        uint startTokenBalance = IERC20(underlyingToken).balanceOf(address(this));
        INFTXLiquidityStaking(liquidityStaking).withdraw(vaultId, amount);

        amount_ = IERC20(underlyingToken).balanceOf(address(this)) - startTokenBalance;
        IERC20(underlyingToken).transfer(msg.sender, amount_);

        emit Withdraw(underlyingToken, amount_, msg.sender);
    }

    /**
     * Harvest possible rewards from strategy.
     *
     * @return amount_ Amount of rewards claimed
     */
    function claimRewards() public returns (uint amount_) {
        amount_ = this.rewardsAvailable();
        INFTXLiquidityStaking(liquidityStaking).claimRewards(vaultId);

        lifetimeRewards += amount_;

        emit Harvest(yieldToken, amount_);
    }

    /**
     * The token amount of reward yield available to be claimed on the connected external
     * platform. Our `claimRewards` function will always extract the maximum yield, so this
     * could essentially return a boolean. However, I think it provides a nicer UX to
     * provide a proper amount and we can determine if it's financially beneficial to claim.
     *
     * This value is stored in terms of the `yieldToken`.
     *
     * @return The available rewards to be claimed
     */
    function rewardsAvailable() external view returns (uint) {
        return ITimelockRewardDistributionToken(yieldToken).dividendOf(address(this));
    }

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     *
     * This value is stored in terms of the `yieldToken`.
     *
     * @return Total rewards generated by strategy
     */
    function totalRewardsGenerated() external view returns (uint) {
        return this.rewardsAvailable() + lifetimeRewards;
    }

    /**
     * The amount of reward tokens generated by the strategy that is allocated to, but has not
     * yet been, minted into FLOOR tokens. This will be calculated by a combination of an
     * internally incremented tally of claimed rewards, as well as the returned value of
     * `rewardsAvailable` to determine pending rewards.
     *
     * This value is stored in terms of the `yieldToken`.
     *
     * @return amount_ Amount of unminted rewards held in the contract
     */
    function unmintedRewards() external view returns (uint amount_) {
        return IERC20(pool).balanceOf(address(this));
    }

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     *
     * @param amount Amount of token to be registered as minted
     */
    function registerMint(address recipient, uint amount) external onlyVault {
        bool success = IERC20(pool).transfer(recipient, amount);
        if (!success) {
            revert UnableToTransferTokens(recipient, amount);
        }
    }

    /**
     * Allows us to restrict calls to only be made by the connected vaultId.
     */
    modifier onlyVault() {
        if (msg.sender != vaultAddr) {
            revert SenderIsNotVault(msg.sender);
        }
        _;
    }
}
