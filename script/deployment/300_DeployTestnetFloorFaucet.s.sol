// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAuthorityControl} from '@floor-interfaces/authorities/AuthorityControl.sol';
import {IAuthorityRegistry} from '@floor-interfaces/authorities/AuthorityRegistry.sol';

import {TestnetFloorFaucet} from '@floor/forks/TestnetFloorFaucet.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract DeployTestnetFloorFaucet is DeploymentScript {

    function run() external deployer {

        // Load and reference our live authority contracts
        IAuthorityControl authorityControl = IAuthorityControl(requireDeployment('AuthorityControl'));
        IAuthorityRegistry authorityRegistry = IAuthorityRegistry(requireDeployment('AuthorityRegistry'));

        // Deploy our faucet
        TestnetFloorFaucet testnetFloorFaucet = new TestnetFloorFaucet(requireDeployment('FloorToken'));

        // Approve the Faucet to mint Floor
        authorityRegistry.grantRole(authorityControl.FLOOR_MANAGER(), address(testnetFloorFaucet));

    }

}
