// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IMercenarySweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';

/**
 * Acts as an interface to allow Optioned Mercenaries to be swept after a collection
 * addition war. This will take a flat amount and sweep as many as it can for the
 * amount provided, prioritised by discount first, then staking order (oldest first).
 *
 * @dev This sweeper makes the assumption that only one collection and amount will
 * be passed through as this is used for the Collection Addition War which, at time
 * of writing, should only allow for a singular winner to be crowned.
 */
contract MercenarySweeper is IMercenarySweeper {
    /// Contract reference to our active {NewCollectionWars} contract
    INewCollectionWars public immutable newCollectionWars;

    /**
     * Sets our immutable {NewCollectionWars} contract reference and casts it's interface.
     */
    constructor(address _newCollectionWars) {
        newCollectionWars = INewCollectionWars(_newCollectionWars);
    }

    /**
     * Actions our Mercenary sweep.
     *
     * @param warIndex The index of the war being executed
     * @param amount The amount allocated to the transaction
     */
    function execute(uint warIndex, uint amount) external payable override returns (uint) {
        // Keep track of the amount spent
        uint startBalance = address(this).balance;

        // Find the token IDs that we intend to buy with
        newCollectionWars.exerciseOptions{value: msg.value}(warIndex, amount);

        // Return the amount spent as a string
        return startBalance - address(this).balance;
    }
}
