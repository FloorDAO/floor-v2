// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SudoswapSweeper} from '@floor/sweepers/Sudoswap.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our collection registry and approves our default collections.
 */
contract UpdateSudoswapSweeperAlphaLambda is DeploymentScript {
    function run() external deployer {
        // Load our sweeper
        SudoswapSweeper sweeper = SudoswapSweeper(requireDeployment('SudoswapSweeper'));

        // Update our alpha and lambda
        sweeper.setAlphaLambda(1.05e9, 0.000005e9);
    }
}
