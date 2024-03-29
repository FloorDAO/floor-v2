// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract SweepWarsMock {
    /// Store internal contracts
    address private immutable collectionRegistry;
    address private immutable treasury;

    /// Store our current epoch iteraction
    uint internal epochIteration;

    /// Store a sample size
    uint public sampleSize = 3;

    /// Store a storage array of collections
    address[] internal approvedCollections;

    /// Hardcoded address to map to the FLOOR token vault
    address public constant FLOOR_TOKEN_VOTE = address(1);

    constructor(address _collectionRegistry, address _treasury) {
        collectionRegistry = _collectionRegistry;
        treasury = _treasury;

        // Add our FLOOR token vote option
        approvedCollections.push(FLOOR_TOKEN_VOTE);
    }

    function userVotingPower(address /* _user */ ) external pure returns (uint) {
        return 0;
    }

    function userVotesAvailable(address /* _user */ ) external pure returns (uint) {
        return 0;
    }

    function vote(address, /* _collection */ uint /* _amount */ ) external {
        //
    }

    function votes(address /* _collection */ ) public pure returns (uint) {
        return 0;
    }

    function votes(address, /* _collection */ uint /* _baseEpoch */ ) public pure returns (uint) {
        return 0;
    }

    function revokeVotes(address[] memory /* _collections */ ) external {
        //
    }

    function revokeAllUserVotes(address /* _account */ ) external {
        //
    }

    function snapshot(uint, /* tokens */ uint /* epoch */ ) external view {
        // Should this be locked down to only run by epoch
        require(msg.sender == address(treasury), 'Not called by Treasury');
    }

    function setSampleSize(uint size) external {
        sampleSize = size;
    }

    function voteOptions() external view returns (address[] memory) {
        return approvedCollections;
    }

    function addCollection(address _collection) public {
        require(msg.sender == address(collectionRegistry), 'Caller not CollectionRegistry');
        approvedCollections.push(_collection);
    }
}
