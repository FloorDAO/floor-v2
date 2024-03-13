// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import {AlphaProVault} from '@charmfi-v2/contracts/AlphaProVault.sol';

import {BaseStrategy, InsufficientPosition} from '@floor/strategies/BaseStrategy.sol';
import {CannotDepositZeroAmount} from '@floor/utils/Errors.sol';


/**
 * Sets up a strategy that interacts with Charm vaults.
 */
contract CharmStrategy is BaseStrategy {
    /// Once our token has been minted, we can store the ID
    AlphaProVault public charmVault;

    /// Store our vault tokens
    IERC20Upgradeable public token0;
    IERC20Upgradeable public token1;

    /// Store the address of our valid rebalancer
    address public rebalancer;

    /**
     * Sets up our contract variables.
     *
     * @param _name The name of the strategy
     * @param _strategyId ID index of the strategy created
     * @param _initData Encoded data to be decoded
     */
    function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer {
        // Set our strategy name
        name = _name;

        // Set our strategy ID
        strategyId = _strategyId;

        // Extract the CharmVault from our initialisation bytes data, and map it the contract
        (address charmVaultAddress, address _rebalancer) = abi.decode(_initData, (address, address));
        charmVault = AlphaProVault(charmVaultAddress);
        rebalancer = _rebalancer;

        // Assign our tokens based on the vault
        token0 = charmVault.token0();
        token1 = charmVault.token1();

        // Set the underlying token as valid to process
        _validTokens[address(token0)] = true;
        _validTokens[address(token1)] = true;

        // Approve the {CharmVault} to use
        token0.approve(address(charmVault), type(uint).max);
        token1.approve(address(charmVault), type(uint).max);

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Adds liquidity against an existing Charm position.
     *
     * @dev We cannot deposit single sided.
     *
     * @param _amount0Desired - The desired amount of token0 that should be supplied
     * @param _amount1Desired - The desired amount of token1 that should be supplied
     * @param _amount0Min - The minimum amount of token0 that should be supplied
     * @param _amount1Min - The minimum amount of token1 that should be supplied
     */
    function deposit(uint _amount0Desired, uint _amount1Desired, uint _amount0Min, uint _amount1Min)
        public
        nonReentrant
        returns (uint shares_, uint amount0_, uint amount1_)
    {
        // Check that we aren't trying to deposit nothing
        if (_amount0Desired + _amount1Desired == 0) {
            revert CannotDepositZeroAmount();
        }

        // Pull the user's tokens into our contract
        token0.transferFrom(msg.sender, address(this), _amount0Desired);
        token1.transferFrom(msg.sender, address(this), _amount1Desired);

        // Increase our strategy position in the Chart vault
        (shares_, amount0_, amount1_) = charmVault.deposit({
            amount0Desired: _amount0Desired,
            amount1Desired: _amount1Desired,
            amount0Min: _amount0Min,
            amount1Min: _amount1Min,
            to: address(this)
        });

        // Send leftovers back to the caller
        token0.transfer(msg.sender, _amount0Desired - amount0_);
        token1.transfer(msg.sender, _amount1Desired - amount1_);

        // Emit our token Deposit events
        emit Deposit(address(token0), amount0_, msg.sender);
        emit Deposit(address(token1), amount1_, msg.sender);

        return (shares_, amount0_, amount1_);
    }

    /**
     * After we have successfully deposited, we should rebalance the vault if it is possible
     * to do so without reverting. This needs to be triggered to add the deposit to the Uniswap
     * pool.
     *
     * Note `rebalance()` will also trigger the vault to select new positions, according to
     * the vault's strategy.
     */
    function rebalance() public {
        require(msg.sender == rebalancer, 'Invalid caller');
        charmVault.rebalance();
    }

    /**
     * Makes a withdrawal of both tokens from our Charm token position.
     *
     * @dev Implements `nonReentrant` through `_withdraw`
     *
     * @param _recipient The recipient of the withdrawal
     * @param _amount0Min The minimum amount of token0 that should be accounted for the burned liquidity
     * @param _amount1Min The minimum amount of token1 that should be accounted for the burned liquidity
     * @param _shares The amount of liquidity to withdraw against
     */
    function withdraw(address _recipient, uint _amount0Min, uint _amount1Min, uint _shares)
        public
        nonReentrant
        onlyOwner
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // Burns liquidity stated, amount0Min and amount1Min are the least you get for
        // burning that liquidity (else reverted).
        (uint amount0, uint amount1) = charmVault.withdraw({
            shares: _shares,
            amount0Min: _amount0Min,
            amount1Min: _amount1Min,
            to: _recipient
        });

        // Ensure that we received tokens from our withdraw
        require(amount0 + amount1 != 0, 'No withdraw output');

        if (amount0 != 0) {
            emit Withdraw(address(token0), amount0, _recipient);
        }

        if (amount1 != 0) {
            emit Withdraw(address(token1), amount1, _recipient);
        }

        tokens_ = validTokens();
        amounts_ = new uint[](2);
        amounts_[0] = amount0;
        amounts_[1] = amount1;
    }

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
     *
     * @dev Implements `nonReentrant` through `_withdraw`
     */
    function withdrawPercentage(address /* recipient */, uint /* percentage */) external view override onlyOwner returns (address[] memory, uint[] memory) {
        // We currently don't implement a percentage withdraw for these strategies as it
        // would require on-chain slippage calculation that could be sandwiched.
        return (validTokens(), new uint[](2));
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view override returns (address[] memory tokens_, uint[] memory amounts_) {
        tokens_ = validTokens();

        // Get our protocol fee
        uint protocolFee = charmVault.protocolFee();

        amounts_ = new uint[](2);
        amounts_[0] = charmVault.accruedProtocolFees0() * 1e6 / protocolFee;
        amounts_[1] = charmVault.accruedProtocolFees1() * 1e6 / protocolFee;
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) external override onlyOwner {
        //
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](2);
        tokens_[0] = address(token0);
        tokens_[1] = address(token1);
    }

}
