// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IEpochManager} from '@floor-interfaces/EpochManager.sol';

interface IEpochManaged {
    /**
     * Gets the address of the contract that currently manages the epoch state of
     * this contract.
     */
    function epochManager() external returns (IEpochManager);

    /**
     * Allows the epoch manager to be updated.
     *
     * @param _epochManager The address of the new epoch manager
     */
    function setEpochManager(address _epochManager) external;
}
