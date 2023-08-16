// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {BaseStrategy, InsufficientPosition} from '@floor/strategies/BaseStrategy.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '@floor/utils/Errors.sol';

/**
 * Supports manual staking of "yield" from an authorised sender. This allows manual
 * yield management from external sources and products that cannot be strictly enforced
 * on-chain otherwise.
 *
 * This differs from the {RevenueStakingStrategy} as it will only drip feed yield to a
 * maximum per epoch.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality.
 *
 * @dev This staking strategy will only accept ERC20 deposits and withdrawals.
 */
contract DistributedRevenueStakingStrategy is AuthorityControl, BaseStrategy, EpochManaged {
    using SafeERC20 for IERC20;

    /// An array of tokens supported by the strategy
    address[] private _tokens;

    /// The maximum amount of yield that can be released per epoch
    uint public maxEpochYield;

    /// Track the amount of token that will be available, and in which epoch
    mapping(uint => uint) public epochYield;

    /// Keep track of the epochs that have > 0 yield
    uint[] private _activeEpochs;

    /**
     * This strategy needs to be authority controlled as we need the ability to update
     * the `maxEpochYield`.
     */
    constructor(address _authority) AuthorityControl(_authority) {}

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

        // Extract information from our initialisation bytes data
        address _epochManager;
        address token;
        (token, maxEpochYield, _epochManager) = abi.decode(_initData, (address, uint, address));

        // Set the underlying token that will be used in various transfer calls
        _tokens.push(token);

        // Set our epoch manager
        _setEpochManager(_epochManager);

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Deposit a token that will be stored as a reward.
     *
     * @param amount Amount of token to deposit
     *
     * @return uint Amount of token registered as rewards
     */
    function depositErc20(uint amount) external nonReentrant whenNotPaused returns (uint) {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Transfer the underlying token from our caller
        IERC20(_tokens[0]).safeTransferFrom(msg.sender, address(this), amount);

        // Emit our event to followers. We need to emit both a `Deposit` and `Harvest` as this
        // strategy essentially merges the two.
        emit Deposit(_tokens[0], amount, msg.sender);
        emit Harvest(_tokens[0], amount);

        // Distribute our yield across the coming epochs
        for (uint _epoch = currentEpoch();;) {
            if (amount == 0) {
                break;
            }

            uint epochAmount = maxEpochYield - epochYield[_epoch];

            if (epochAmount != 0) {
                if (epochYield[_epoch] == 0) {
                    _activeEpochs.push(_epoch);
                }

                unchecked {
                    uint k = (epochAmount < amount) ? epochAmount : amount;
                    amount -= k;
                    epochYield[_epoch] += k;
                }
            }

            unchecked {
                ++_epoch;
            }
        }

        return amount;
    }

    /**
     * Withdraws an amount of our position from the strategy.
     *
     * @param recipient The recipient address of the withdrawal
     *
     * @return uint Amount of the token returned
     */
    function withdrawErc20(address recipient) external nonReentrant onlyOwner returns (uint) {
        uint _currentEpoch = currentEpoch();
        uint amount;

        // Capture our starting balance
        for (uint i; i < _activeEpochs.length;) {
            if (_activeEpochs[i] <= _currentEpoch) {
                // Add to amount we can extract
                amount += epochYield[_activeEpochs[i]];

                // Remove element
                _activeEpochs[i] = _activeEpochs[_activeEpochs.length - 1];
                _activeEpochs.pop();
            } else {
                unchecked {
                    ++i;
                }
            }
        }

        if (amount != 0) {
            // Transfer the received token to the caller
            IERC20(_tokens[0]).safeTransfer(recipient, amount);

            // Fire an event to show amount of token claimed and the recipient
            emit Withdraw(_tokens[0], amount, recipient);
        }

        lifetimeRewards[_tokens[0]] += amount;

        // As we have a 1:1 mapping of tokens, we can just return the initial withdrawal amount
        return amount;
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external view override returns (address[] memory tokens_, uint[] memory amounts_) {
        uint _currentEpoch = currentEpoch();
        uint amount;

        for (uint i; i < _activeEpochs.length;) {
            if (_activeEpochs[i] <= _currentEpoch) {
                amount += epochYield[_activeEpochs[i]];
            }

            unchecked {
                ++i;
            }
        }

        tokens_ = _tokens;
        amounts_ = new uint[](1);
        amounts_[0] = amount;
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) external override onlyOwner {
        /*  */
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view override returns (address[] memory) {
        return _tokens;
    }

    /**
     * Allows the `maxEpochYield` to be updated by an approved caller.
     */
    function setMaxEpochYield(uint _maxEpochYield) external onlyRole(STRATEGY_MANAGER) {
        require(_maxEpochYield != 0, 'Cannot set zero yield');
        maxEpochYield = _maxEpochYield;
    }
}
