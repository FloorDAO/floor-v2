// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

import {AuthorityControl} from '../authorities/AuthorityControl.sol';

import {INFTXInventoryStaking} from '../../interfaces/nftx/NFTXInventoryStaking.sol';
import {IBaseStrategy} from '../../interfaces/strategies/BaseStrategy.sol';

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
contract NFTXInventoryStakingStrategy is AuthorityControl, IBaseStrategy, Initializable {
    /// The human-readable name of the inventory strategy
    bytes32 public immutable name;

    /// The vault ID that the strategy is attached to
    uint public vaultId;

    /// The address of the vault the strategy is attached to
    address public vaultAddr;

    /// TODO: Needed?
    address public pool;

    /// The underlying token will be the same as the address of the NFTX vault.
    address public underlyingToken;

    /// The reward yield will be a vault xToken as defined by the InventoryStaking contract.
    address public yieldToken;

    /// Address of the NFTX Inventory Staking contract
    address public inventoryStaking;

    /// Address of the Floor {Treasury}
    address public treasury;

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
     * Sets our strategy name and initializes our {AuthorityControl}.
     *
     * @param _name Human-readable name of the strategy
     * @param _authority {AuthorityRegistry} contract address
     */
    constructor(bytes32 _name, address _authority) AuthorityControl(_authority) {
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
        (address _pool, address _underlyingToken, address _yieldToken, address _inventoryStaking, address _treasury) =
            abi.decode(initData, (address, address, address, address, address));

        pool = _pool;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        vaultId = _vaultId;
        vaultAddr = _vaultAddr;

        inventoryStaking = _inventoryStaking;
        treasury = _treasury;
    }

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
     * @param amount Amount of underlying token to deposit
     *
     * @return amount_ Amount of yield token returned from NFTX
     */
    function deposit(uint amount) external onlyVault returns (uint amount_) {
        // Prevent users from trying to deposit nothing
        require(amount != 0, 'Cannot deposit 0');

        // Capture our starting balance
        uint startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));

        // Transfer the underlying token from our caller
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);

        // Approve the NFTX contract against our underlying token
        IERC20(underlyingToken).approve(inventoryStaking, amount);

        // Deposit the token into the NFTX contract
        INFTXInventoryStaking(inventoryStaking).deposit(vaultId, amount);

        // Determine the amount of yield token returned from our deposit
        amount_ = IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;
        deposits += amount_;

        // Emit our event to followers
        emit Deposit(underlyingToken, amount, msg.sender);
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @param amount Amount of yield token to withdraw
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdraw(uint amount) external onlyVault returns (uint amount_) {
        // Prevent users from trying to claim nothing
        require(amount != 0, 'Cannot claim 0');

        // Capture our starting balance
        uint startTokenBalance = IERC20(underlyingToken).balanceOf(address(this));

        // Process our withdrawal against the NFTX contract
        INFTXInventoryStaking(inventoryStaking).withdraw(vaultId, amount);

        // Determine the amount of `underlyingToken` received
        amount_ = IERC20(underlyingToken).balanceOf(address(this)) - startTokenBalance;

        // Transfer the received token to the caller
        IERC20(underlyingToken).transfer(msg.sender, amount_);

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(underlyingToken, amount_, msg.sender);
    }

    /**
     * Harvest possible rewards from strategy.
     *
     * @return amount_ Amount of rewards claimed
     */
    function claimRewards() public returns (uint amount_) {
        amount_ = this.rewardsAvailable();
        if (amount_ != 0) {
            bool success = INFTXInventoryStaking(inventoryStaking).receiveRewards(vaultId, amount_);
            require(success, 'Unable to claim rewards');
        }

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
        return INFTXInventoryStaking(inventoryStaking).balanceOf(vaultId, address(this));
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
     * @return Amount of unminted rewards held in the contract
     */
    function unmintedRewards() external view returns (uint) {
        return IERC20(yieldToken).balanceOf(address(this));
    }

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     *
     * @param amount Amount of token to be registered as minted
     */
    function registerMint(uint amount) external onlyRole(TREASURY_MANAGER) {}

    /**
     * Allows us to restrict calls to only be made by the connected vaultId.
     */
    modifier onlyVault() {
        require(msg.sender == vaultAddr);
        _;
    }
}
