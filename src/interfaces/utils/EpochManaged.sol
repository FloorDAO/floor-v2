// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IEpochManager} from '@floor-interfaces/EpochManager.sol';

interface IEpochManaged {
    /**
     *  ..
     */
    function epochManager() external returns (IEpochManager);

    /**
     * ..
     */
    function setEpochManager(address _epochManager) external;
}
