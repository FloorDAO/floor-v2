// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IEpochManager} from '@floor-interfaces/EpochManager.sol';


abstract contract EpochManaged is Ownable {

    /// ..
    IEpochManager public epochManager;

    /**
     * ..
     */
    function setEpochManager(address _epochManager) external virtual onlyOwner {
        epochManager = IEpochManager(_epochManager);
    }

    /**
     * ..
     */
    function currentEpoch() internal view virtual returns (uint) {
        return epochManager.currentEpoch();
    }

    /**
     * ..
     */
    modifier onlyEpochManager() {
        require(msg.sender == address(epochManager), 'Only EpochManager can call');
        _;
    }

}
