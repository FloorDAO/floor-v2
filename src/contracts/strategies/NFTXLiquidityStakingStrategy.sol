// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../authorities/AuthorityControl.sol";

import "../../interfaces/nftx/NFTXLiquidityStaking.sol";
import "../../interfaces/nftx/TimelockRewardDistributionToken.sol";
import "../../interfaces/strategies/BaseStrategy.sol";

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
contract NFTXLiquidityStakingStrategy is AuthorityControl, IBaseStrategy, Initializable {
    uint256 public vaultId;
    address public vaultAddr;
    address public pool;

    /**
     * The underlying token will be a liquidity SLP as defined by the {LiquidityStaking} contract.
     */
    address public underlyingToken; // SLP

    /**
     * The reward yield token will be the token defined in the {LiquidityStaking} contract.
     */
    address public yieldToken; // xSLP

    bytes32 public name;

    address public liquidityStaking;
    address public treasury;

    /**
     * This will return the internally tracked value of tokens that have been minted into
     * FLOOR by the {Treasury}.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint256 public mintedRewards;

    /**
     * This will return the internally tracked value of tokens that have been claimed by
     * the strategy, regardless of if they have been minted into FLOOR.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint256 private lifetimeRewards;

    /**
     * This will return the internally tracked value of all deposits made into the strategy.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint256 public deposits;

    /**
     * ...
     */
    constructor(bytes32 _name, address _authority) AuthorityControl(_authority) {
        name = _name;
    }

    /**
     * ...
     */
    function initialize(uint256 _vaultId, address _vaultAddr, bytes memory initData) public initializer {
        (address _pool, address _underlyingToken, address _yieldToken, address _liquidityStaking, address _treasury) =
            abi.decode(initData, (address, address, address, address, address));

        pool = _pool;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        vaultId = _vaultId;
        vaultAddr = _vaultAddr;

        liquidityStaking = _liquidityStaking;
        treasury = _treasury;

        IERC20(underlyingToken).approve(_liquidityStaking, type(uint256).max);
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
    function deposit(uint256 amount) external onlyVault returns (uint256 xTokensReceived) {
        require(amount != 0, "Cannot deposit 0");

        // Get the SLP token from the user
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);

        // Get our xSLP starting balance
        uint256 startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));

        // Stake our SLP to get xSLP back
        INFTXLiquidityStaking(liquidityStaking).deposit(vaultId, amount);

        // Calculate how much xSLP was returned
        xTokensReceived = IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;
        deposits += xTokensReceived;

        emit Deposit(underlyingToken, amount, msg.sender);
    }

    /**
     * Allows the user to burn xToken to receive base their original token.
     */
    function withdraw(uint256 amount) external onlyVault returns (uint256 amount_) {
        require(amount != 0, "Cannot claim 0");

        uint256 startTokenBalance = IERC20(underlyingToken).balanceOf(address(this));
        INFTXLiquidityStaking(liquidityStaking).withdraw(vaultId, amount);

        amount_ = IERC20(underlyingToken).balanceOf(address(this)) - startTokenBalance;
        IERC20(underlyingToken).transfer(msg.sender, amount_);

        emit Withdraw(underlyingToken, amount_, msg.sender);
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
    function claimRewards() public returns (uint256 amount_) {
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
     */
    function rewardsAvailable() external view returns (uint256) {
        return ITimelockRewardDistributionToken(yieldToken).dividendOf(address(this));
    }

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function totalRewardsGenerated() external view returns (uint256) {
        return this.rewardsAvailable() + lifetimeRewards;
    }

    /**
     * The amount of reward tokens generated by the strategy that is allocated to, but has not
     * yet been, minted into FLOOR tokens. This will be calculated by a combination of an
     * internally incremented tally of claimed rewards, as well as the returned value of
     * `rewardsAvailable` to determine pending rewards.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function unmintedRewards() external view returns (uint256 amount_) {
        return IERC20(pool).balanceOf(address(this));
    }

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     */
    function registerMint(uint256 amount) external onlyRole(TREASURY_MANAGER) {}

    /**
     * Allows us to restrict calls to only be made by the connected vaultId.
     */
    modifier onlyVault() {
        require(msg.sender == vaultAddr);
        _;
    }
}
