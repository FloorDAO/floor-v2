// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SudoswapCustomSweeper} from '@floor/sweepers/SudoswapCustom.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract DeploySudoswapCustomSweeper is DeploymentScript {

    function run() external deployer {
        // Reference our {Treasury}
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Deploy the SudoswapCustomSweeper
        SudoswapCustomSweeper sweeper = new SudoswapCustomSweeper({
            _treasury: payable(address(treasury)),
            _pairFactory: payable(0xA020d57aB0448Ef74115c112D18a9C231CC86000), // mainnet
            _gdaCurve: 0x1fD5876d4A3860Eb0159055a3b7Cb79fdFFf6B67 // mainnet
            // _pairFactory: payable(0x5bfE2ef160EaaAa4aFa89A8fa09775b6580162c9),  // sepolia
            // _gdaCurve: 0x2286e66cc3b3f15aE6d88164F618F98f1Ce21581  // sepolia
        });

        // Approve the sweeper
        treasury.approveSweeper(address(sweeper), true);

        // Store our new ManualSweeper
        storeDeployment('SudoswapCustomSweeper', address(sweeper));
    }

}
