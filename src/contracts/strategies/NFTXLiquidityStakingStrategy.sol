// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../../interfaces/nftx/NFTXLiquidityStaking.sol';
import '../../interfaces/nftx/TimelockRewardDistributionToken.sol';
import '../../interfaces/strategies/BaseStrategy.sol';
import '../../interfaces/strategies/NFTXLiquidityStakingStrategy.sol';


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
contract NFTXLiquidityStakingStrategy is IBaseStrategy, INFTXLiquidityStakingStrategy {

    uint public immutable vaultId;
    address public immutable pool;
    address public immutable underlyingToken;  // SLP
    address public immutable yieldToken;       // xSLP

    bytes32 public immutable name;

    address public immutable liquidityStaking;
    address public immutable treasury;

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
    uint public lifetimeRewards;

    /**
     * This will return the internally tracked value of all deposits made into the strategy.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint public deposits;

    /**
     *
     */
    constructor (
        bytes32 _name,
        address _pool,
        address _underlyingToken,
        address _yieldToken,
        uint _vaultId,
        address _liquidityStaking,
        address _treasury
    ) {
        name = _name;

        pool = _pool;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        vaultId = _vaultId;

        liquidityStaking = _liquidityStaking;
        treasury = _treasury;

        ERC20(underlyingToken).approve(_liquidityStaking, type(uint).max);
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
     */
    function deposit(uint amount) payable external returns (uint xTokensReceived) {
        require(amount > 0, 'Cannot deposit 0');

        // Get the SLP token from the user
        ERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);

        // Get our xSLP starting balance
        uint startXTokenBalance = ERC20(yieldToken).balanceOf(address(this));

        // Stake our SLP to get xSLP back
        INFTXLiquidityStaking(liquidityStaking).deposit(vaultId, amount);

        // Calculate how much xSLP was returned
        xTokensReceived = ERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;
        deposits += xTokensReceived;
    }

    /**
     * Harvest possible rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * - Get the vaultID from the underlying address
     * - LiquidityStaking.claimRewards
     * - Distribute yield
     */
    function claimRewards() external returns (uint amount_) {
        amount_ = ITimelockRewardDistributionToken(yieldToken).dividendOf(address(this));
        INFTXLiquidityStaking(liquidityStaking).claimRewards(vaultId);
    }

    /**
     * Allows a staked user to exit their strategy position, burning all corresponding
     * xSLP to retrieve all their underlying tokens.
     */
    function exit() external returns (uint returnAmount_) {
        returnAmount_ = ERC20(underlyingToken).balanceOf(address(this));
        INFTXLiquidityStaking(liquidityStaking).withdraw(vaultId, returnAmount_);
    }

    /**
     * The token amount of reward yield available to be claimed on the connected external
     * platform. Our `claimRewards` function will always extract the maximum yield, so this
     * could essentially return a boolean. However, I think it provides a nicer UX to
     * provide a proper amount and we can determine if it's financially beneficial to claim.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function rewardsAvailable() external view returns (uint) {
        return ITimelockRewardDistributionToken(yieldToken).dividendOf(address(this));
    }

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function totalRewardsGenerated() external view returns (uint) {
        return ITimelockRewardDistributionToken(yieldToken).dividendOf(address(this)) + ERC20(pool).balanceOf(address(this)) + mintedRewards;
    }

    /**
     * The amount of reward tokens generated by the strategy that is allocated to, but has not
     * yet been, minted into FLOOR tokens. This will be calculated by a combination of an
     * internally incremented tally of claimed rewards, as well as the returned value of
     * `rewardsAvailable` to determine pending rewards.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function unmintedRewards() external view returns (uint amount_) {
        return ERC20(pool).balanceOf(address(this));
    }

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     */
    function registerMint(uint amount) external {}

}
