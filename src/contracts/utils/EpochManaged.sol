// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IEpochManager} from '@floor-interfaces/EpochManager.sol';

abstract contract EpochManaged is Ownable {
    /// Stores the current {EpochManager} contract
    IEpochManager public epochManager;

    /**
     * Allows an updated {EpochManager} address to be set.
     */
    function setEpochManager(address _epochManager) external virtual onlyOwner {
        _setEpochManager(_epochManager);
    }

    function _setEpochManager(address _epochManager) internal virtual {
        epochManager = IEpochManager(_epochManager);
    }

    /**
     * Gets the current epoch from our {EpochManager}.
     */
    function currentEpoch() internal view virtual returns (uint) {
        return epochManager.currentEpoch();
    }

    /**
     * Checks that the contract caller is the {EpochManager}.
     */
    modifier onlyEpochManager() {
        require(msg.sender == address(epochManager), 'Only EpochManager can call');
        _;
    }
}
