// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {BaseStrategy} from '@floor/strategies/BaseStrategy.sol';

/**
 * Acts as a strategy that will revert on any of the calls made. This is used in tests
 * to ensure that we can correctly handle this occurence and not brick the system when
 * handling them.
 */
contract RevertingStrategy is BaseStrategy {
    /// An array of tokens supported by the strategy
    address[] private _tokens;

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

        // Extract information from our initialisation bytes data
        (_tokens) = abi.decode(_initData, (address[]));

        // Set the underlying token as valid to process
        for (uint i; i < _tokens.length;) {
            _validTokens[_tokens[i]] = true;
            unchecked {
                ++i;
            }
        }

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Withdraws an amount of our position from the strategy.
     *
     * @param amount Amount of token to withdraw
     *
     * @return uint Amount of the token returned
     */
    function withdrawErc20(address recipient, address token, uint amount) external onlyOwner returns (uint) {
        revert('Prevent Withdraw');
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external view override returns (address[] memory tokens_, uint[] memory amounts_) {
        revert('Prevent Available');
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) external override onlyOwner {
        revert('Prevent harvest');
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view override returns (address[] memory) {
        return _tokens;
    }
}
