// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Replaces our existing Manual Sweeper due to change in code. Will keep nonce in sync even
 * for new chains.
 */
contract ReplaceManualSweeper is DeploymentScript {

    function run() external deployer {
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Disable 0x92074bCDe36DfCd5f8fa5D2C5219c2963B77a904 (existing ManualSweeper)
        treasury.approveSweeper(0x92074bCDe36DfCd5f8fa5D2C5219c2963B77a904, false);

        // Deploy new ManualSweeper
        ManualSweeper manualSweeper = new ManualSweeper(payable(address(treasury)));

        // Approve the sweeper
        treasury.approveSweeper(address(manualSweeper), true);

        // Update the sweeper router to set this new address for WETH
        // @dev This is done by the manager, not the deployer

        // Store our new ManualSweeper
        storeDeployment('ManualSweeper', address(manualSweeper));
    }

}
