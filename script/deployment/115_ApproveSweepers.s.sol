// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {SudoswapSweeper} from '@floor/sweepers/Sudoswap.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our treasury actions.
 */
contract ApproveSweepers is DeploymentScript {

    function run() external deployer {
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Load our sweepers and approve for sweeping
        address manualSweeper = getDeployment('ManualSweeper');
        if (manualSweeper != address(0)) {
            treasury.approveSweeper(requireDeployment('ManualSweeper'), true);
        } else {
            manualSweeper = address(new ManualSweeper());
            treasury.approveSweeper(manualSweeper, true);
            storeDeployment('ManualSweeper', manualSweeper);
        }

        address sudoswapSweeper = getDeployment('SudoswapSweeper');
        if (sudoswapSweeper != address(0)) {
            treasury.approveSweeper(requireDeployment('SudoswapSweeper'), true);
        } else {
            sudoswapSweeper = address(new SudoswapSweeper({
                _treasury: payable(address(treasury)),
                // _pairFactory: payable(0xA020d57aB0448Ef74115c112D18a9C231CC86000), // mainnet
                // _gdaCurve: 0x1fD5876d4A3860Eb0159055a3b7Cb79fdFFf6B67 // mainnet
                _pairFactory: payable(0x5bfE2ef160EaaAa4aFa89A8fa09775b6580162c9),  // sepolia
                _gdaCurve: 0x2286e66cc3b3f15aE6d88164F618F98f1Ce21581  // sepolia
            }));

            treasury.approveSweeper(sudoswapSweeper, true);
            storeDeployment('SudoswapSweeper', sudoswapSweeper);
        }

        // treasury.approveSweeper(requireDeployment('GemSweeper'), true);
    }

}
