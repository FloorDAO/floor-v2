// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract TreasuryMock {

    /// Stores a list of approved sweeper contracts
    mapping(address => bool) public approvedSweepers;

    /**
     * Allows a sweeper contract to be approved or uapproved.
     */
    function approveSweeper(address _sweeper, bool _approved) external {
        approvedSweepers[_sweeper] = _approved;
    }

    receive () payable external {}

}
