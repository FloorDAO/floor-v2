// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {CowSwapSweeper} from '@floor/sweepers/CowSwap.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

contract GetCowSwapSweeperBytes is DeploymentScript {

    function run() external {

        CowSwapSweeper.Pool[] memory pools = new CowSwapSweeper.Pool[](1);
        pools[0] = CowSwapSweeper.Pool({
            pool: 0x2c2511250C3561F6E5f8999Ac777d9465E7e27FA,
            fee: 300,       // 0.3%
            slippage: 10_0, // 10%
            partSize: 2_00  // 2 ether
        });

        console.logBytes(abi.encode(pools));

    }

}
