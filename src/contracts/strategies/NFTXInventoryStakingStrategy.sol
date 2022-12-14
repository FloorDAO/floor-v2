// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';

import '../../interfaces/nftx/NFTXInventoryStaking.sol';
import '../../interfaces/strategies/BaseStrategy.sol';
import '../../interfaces/strategies/NFTXInventoryStakingStrategy.sol';


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
contract NFTXInventoryStakingStrategy is IBaseStrategy, INFTXInventoryStakingStrategy, Initializable {

    uint public vaultId;
    address public pool;
    address public underlyingToken;
    address public yieldToken;

    bytes32 public name;

    address public inventoryStaking;
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
    uint public lifetimeRewards;

    /**
     * This will return the internally tracked value of all deposits made into the strategy.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    uint public deposits;

    /**
     * ...
     */
    constructor () {}

    /**
     * ...
     */
    function initialize(bytes memory initData) public initializer {
        (
            bytes32 _name,
            address _pool,
            address _underlyingToken,
            address _yieldToken,
            uint _vaultId,
            address _inventoryStaking,
            address _treasury
        ) = abi.decode(initData, (bytes32, address, address, address, uint, address, address));

        name = _name;

        pool = _pool;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        vaultId = _vaultId;

        inventoryStaking = _inventoryStaking;
        treasury = _treasury;

        IERC20(underlyingToken).approve(_inventoryStaking, type(uint).max);
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
     */
    function deposit(uint amount) external returns (uint) {
        require(amount > 0, 'Cannot deposit 0');

        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);

        uint startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));
        INFTXInventoryStaking(inventoryStaking).deposit(vaultId, amount);
        deposits += amount;
        return IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;
    }

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
    function claimRewards(uint amount) external returns (uint) {
        require(amount > 0, 'Cannot claim 0');

        INFTXInventoryStaking(inventoryStaking).withdraw(vaultId, amount);
        lifetimeRewards += amount;
        return amount;
    }

    /**
     * Allows a staked user to exit their strategy position, burning all corresponding
     * xToken to retrieve all their underlying tokens.
     */
    function exit() external returns (uint256 returnAmount_) {
        returnAmount_ = IERC20(yieldToken).balanceOf(address(this));
        lifetimeRewards += returnAmount_;
        INFTXInventoryStaking(inventoryStaking).withdraw(vaultId, returnAmount_);
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
        return IERC20(yieldToken).balanceOf(address(this)) - deposits;
    }

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     *
     * This value is stored in terms of the `yieldToken`.
     */
    function totalRewardsGenerated() external view returns (uint) {
        return IERC20(yieldToken).balanceOf(address(this)) + mintedRewards - deposits;
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
        return IERC20(yieldToken).balanceOf(address(this)) - deposits;
    }

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     */
    function registerMint(uint amount) external {}

}
