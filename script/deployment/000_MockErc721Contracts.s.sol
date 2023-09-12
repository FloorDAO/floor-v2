// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Helper contract to deploy a number of mock ERC721 contracts.
 */
contract DeployErc721Mock is DeploymentScript {
    function run() external deployer {
        // Deploy a mock erc721 contracts that can be used for testing in the
        // collection registry.
        new ERC721Mock();
    }
}
