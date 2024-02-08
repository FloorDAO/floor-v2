// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CowSwapSweeper} from '@floor/sweepers/CowSwap.sol';
import {SweeperRouter} from '@floor/sweepers/SweeperRouter.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our CowSwap Sweeper and Sweeper Router contracts.
 */
contract DeployCowSwapSweeperAndSweeperRouter is DeploymentScript {

    function run() external deployer {
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Deploy our sweeper contract. The CowSwap addresses are the same across all
        // relevant blockchains.
        CowSwapSweeper cowswapSweeper = new CowSwapSweeper({
            _treasury: payable(address(treasury)),
            _relayer: 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110,
            _composableCow: 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74,
            _twapHandler: 0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5
        });

        SweeperRouter sweeperRouter = new SweeperRouter(
            requireDeployment('AuthorityRegistry'),
            payable(address(treasury))
        );

        treasury.approveSweeper(address(cowswapSweeper), true);
        treasury.approveSweeper(address(sweeperRouter), true);

        storeDeployment('CowSwapSweeper', address(cowswapSweeper));
        storeDeployment('SweeperRouter', address(sweeperRouter));
    }

}
