// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 */
contract ExecuteSweep is DeploymentScript {

    // Our wallet
    address WALLET = 0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348;

    function run() external deployer {

        EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));
        ManualSweeper manualSweeper = ManualSweeper(requireDeployment('ManualSweeper'));
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        /*
        // Ensure our {Treasury} has enough ETH for the sweep. This also checks if
        // we need to wrap additional WETH from our dev wallet's ETH.
        if (treasury.weth().balanceOf(address(treasury)) < 0.5 ether) {
            // Ensure our wallet has enough WETH to send
            uint walletWeth = treasury.weth().balanceOf(WALLET);
            if (walletWeth < 5 ether) {
                treasury.weth().deposit{value: 5 ether - walletWeth}();
            }

            // Transfer the WETH to the {Treasury}
            treasury.weth().transfer(address(treasury), 5 ether);
        }

        // Ensure that our {Treasury} min sweep amount is correct
        if (treasury.minSweepAmount() != 0.1 ether) {
            treasury.setMinSweepAmount(0.1 ether);
        }
        */

        // Action a sweep against the previous epoch
        /*
        treasury.sweepEpoch(
            epochManager.currentEpoch() - 1,
            address(manualSweeper),
            'Example test sweep data',
            0
        );
        */

        // Action a SudoSwap Sweep
        treasury.sweepEpoch(8, requireDeployment('SudoswapSweeper'), '', 0);

    }

}
