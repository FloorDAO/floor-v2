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
     * @return uint Amount of the token returned
     */
    function withdrawErc20(address /* recipient */, address /* token */, uint /* amount */) external view onlyOwner returns (uint) {
        revert('Prevent Withdraw');
    }

    /**
     * Allows for liquidation of the strategy based on a percentage value. This withdraws the
     * percentage of the underlying tokens that were initially deposited, using the relevant
     * withdraw functions.
     *
     * The tokens will be withdrawn to the caller of the function, so relevant permissions should
     * be checked.
     */
    function withdrawPercentage(address /* recipient */, uint /* percentage */) external override view onlyOwner returns (address[] memory, uint[] memory) {
        revert('Prevent Withdraw Percentage');
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public pure override returns (address[] memory, uint[] memory) {
        revert('Prevent Available');
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address /* _recipient */) external override view onlyOwner {
        revert('Prevent Harvest');
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory) {
        return _tokens;
    }
}
