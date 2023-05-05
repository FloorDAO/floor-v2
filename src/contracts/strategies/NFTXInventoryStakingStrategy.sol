// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '../utils/Errors.sol';

import {BaseStrategy, InsufficientPosition, UnableToTransferTokens, ZeroAmountReceivedFromWithdraw} from '@floor/strategies/BaseStrategy.sol';

import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';


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
contract NFTXInventoryStakingStrategy is BaseStrategy {

    /// The NFTX vault ID that the strategy is attached to
    uint public vaultId;

    /// The underlying token will be the same as the address of the NFTX vault.
    address public underlyingToken;

    /// The reward yield will be a vault xToken as defined by the InventoryStaking contract.
    address public yieldToken;

    /// Address of the NFTX Inventory Staking contract
    address public inventoryStaking;

    /// ..
    uint public deposits;

    /**
     * Sets up our contract variables.
     *
     * @param _name The name of the strategy
     * @param _strategyId ID index of the strategy created
     * @param _initData Encoded data to be decoded
     */
    function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer {
        // Set our vault name
        name = _name;

        // Set our strategy ID
        strategyId = _strategyId;

        // Extract the NFTX information from our initialisation bytes data
        (uint _vaultId, address _underlyingToken, address _yieldToken, address _inventoryStaking) = abi.decode(_initData, (uint, address, address, address));

        // Map our NFTX information
        vaultId = _vaultId;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;

        // Map our NFTX Inventory Staking contract address
        inventoryStaking = _inventoryStaking;

        // Set the underlying token as valid to process
        _validTokens[underlyingToken] = true;
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
     * @return amounts_ Amount of yield token returned from NFTX
     */
    function deposit(address[] memory /* tokens */, uint[] memory amounts) external nonReentrant whenNotPaused returns (uint[] memory amounts_) {
        // Since we only process our underlying token for NFTX Inventory Staking, we can just directly
        // reference the first amounts array element.
        uint amount = amounts[0];

        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Capture our starting balance
        uint startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));

        // Transfer the underlying token from our caller
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);
        deposits += amount;

        // Approve the NFTX contract against our underlying token
        IERC20(underlyingToken).approve(inventoryStaking, amount);

        // Deposit the token into the NFTX contract
        INFTXInventoryStaking(inventoryStaking).deposit(vaultId, amount);

        // Determine the amount of yield token returned from our deposit
        amounts_ = new uint[](1);
        amounts_[0] = IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;

        // Increase the user's position and the total position for the vault
        unchecked {
            position[yieldToken] += amounts_[0];
        }

        // Emit our event to followers
        emit Deposit(underlyingToken, amount, msg.sender);
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @param amounts Amount of yield token to withdraw
     *
     * @return amounts_ Amount of the underlying token returned
     */
    function withdraw(address[] memory /* tokens */, uint[] memory amounts) external nonReentrant onlyOwner returns (uint[] memory amounts_) {
        // Since we only process our underlying token for NFTX Inventory Staking, we can just directly
        // reference the first amounts array element.
        uint amount = amounts[0];

        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        // Ensure our user has sufficient position to withdraw from
        if (amount > position[yieldToken]) {
            revert InsufficientPosition(yieldToken, amount, position[yieldToken]);
        }

        // Capture our starting balance
        uint startTokenBalance = IERC20(underlyingToken).balanceOf(address(this));

        // Process our withdrawal against the NFTX contract
        INFTXInventoryStaking(inventoryStaking).withdraw(vaultId, amount);

        // Determine the amount of `underlyingToken` received
        amounts_ = new uint[](1);
        amounts_[0] = IERC20(underlyingToken).balanceOf(address(this)) - startTokenBalance;
        if (amounts_[0] == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the received token to the caller
        IERC20(underlyingToken).transfer(msg.sender, amounts_[0]);

        unchecked {
            deposits -= amounts_[0];

            // We can now reduce the users position and total position held by the vault
            position[yieldToken] -= amount;
        }

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(underlyingToken, amounts_[0], msg.sender);
    }

    /**
     * Harvest possible rewards from strategy.
     *
     * TODO: Should be locked down, or return to {Treasury}
     *
     * @return tokens_ Tokens claimed
     * @return amounts_ Amount of rewards claimed
     */
    function _claimRewards() internal override returns (address[] memory tokens_, uint[] memory amounts_) {
        tokens_ = new address[](1);
        tokens_[0] = underlyingToken;

        amounts_ = new uint[](1);
        amounts_[0] = this.rewardsAvailable(underlyingToken);

        if (amounts_[0] != 0) {
            INFTXInventoryStaking(inventoryStaking).withdraw(vaultId, amounts_[0]);
            IERC20(underlyingToken).transfer(msg.sender, amounts_[0]);

            unchecked {
                lifetimeRewards[underlyingToken] += amounts_[0];
            }
        }

        emit Harvest(underlyingToken, amounts_[0]);
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
    function rewardsAvailable(address /* token */) external view returns (uint) {
        // Get the amount of rewards avaialble to claim
        uint userTokens = deposits;

        // Get the xToken balance held by the strategy
        uint xTokenUserBal = IERC20(yieldToken).balanceOf(address(this));

         // Get the number of vTokens valued per xToken in wei
        uint shareValue = INFTXInventoryStaking(inventoryStaking).xTokenShareValue(vaultId);
        uint reqXTokens = (userTokens * 1e18) / shareValue;

        // If we require more xTokens than are held to allow our users to withdraw their
        // staked NFTs (NFTX dust issue) then we need to catch this and return zero.
        if (reqXTokens > xTokenUserBal) {
            return 0;
        }

        // Get the total rewards available above what would be required for a user
        // to mint their tokens back out of the vault.
        return xTokenUserBal - reqXTokens;
    }

    /**
     * Total rewards generated by the strategy in all time. This is pure bragging rights.
     *
     * This value is stored in terms of the `yieldToken`.
     *
     * @return Total rewards generated by strategy
     */
    function totalRewardsGenerated(address token) external view returns (uint) {
        return this.rewardsAvailable(token) + lifetimeRewards[token];
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
    function unmintedRewards(address token) external override view returns (uint) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * This is a call that will only be available for the {Treasury} to indicate that it
     * has minted FLOOR and that the internally stored `mintedRewards` integer should be
     * updated accordingly.
     *
     * @dev Only to be called by the {Treasury}
     *
     * @param amount Amount of token to be registered as minted
     */
    function registerMint(address recipient, address /* token */, uint amount) external onlyOwner {
        bool success = IERC20(yieldToken).transfer(recipient, amount);
        if (!success) revert UnableToTransferTokens(recipient, amount);

        unchecked {
            mintedRewards[yieldToken] += amount;
        }

        // emit MintRegistered(recipient, yieldToken, amount);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view returns (address[] memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = underlyingToken;
        return tokens_;
    }

}
