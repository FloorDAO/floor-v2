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
        ERC721Mock mock = ERC721Mock(0xDc110028492D1baA15814fCE939318B6edA13098);

        for (uint i; i < 50; ++i) {
            mock.mint(0x84f4840E47199F1090cEB108f74C5F332219539A, 400 + i);
        }
    }
}
