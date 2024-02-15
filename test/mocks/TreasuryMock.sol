// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

contract TreasuryMock {

    /// Stores a list of approved sweeper contracts
    mapping(address => bool) public approvedSweepers;

    /**
     * Allows a sweeper contract to be approved or uapproved.
     */
    function approveSweeper(address _sweeper, bool _approved) external {
        approvedSweepers[_sweeper] = _approved;
    }

    /**
     * Allows a sweep to be executed with passed parameters.
     */
    function sweepEpoch(address _sweeper, address[] memory _collections, uint[] memory _amounts, bytes memory _data) public {
        uint msgValue;
        for (uint i; i < _amounts.length; ++i) {
            msgValue += _amounts[i];
        }

        // Action our sweep. If we don't hold enough ETH to supply the message value then
        // we expect this call to revert. This call may optionally return a message that
        // will be stored against the struct.
        ISweeper(_sweeper).execute{value: msgValue}(_collections, _amounts, _data);
    }

    receive () payable external {}

}
