// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CowSwapSweeper} from '@floor/sweepers/CowSwap.sol';
import {SweeperRouter} from '@floor/sweepers/SweeperRouter.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract ConfigureSweeperRouter is DeploymentScript {

    function run() external deployer {

        SweeperRouter router = SweeperRouter(requireDeployment('SweeperRouter'));

        // Mainnet
        // ..

        // Sepolia
        router.setSweeper({
            _collection: 0x3d7E741B5E806303ADbE0706c827d3AcF0696516, // CoolCats
            _sweeper: requireDeployment('SudoswapSweeper'),
            _data: ''
        });

        router.setSweeper({
            _collection: 0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6, // Milady
            _sweeper: requireDeployment('SudoswapSweeper'),
            _data: ''
        });

        CowSwapSweeper.Pool[] memory pools = new CowSwapSweeper.Pool[](1);
        pools[0] = CowSwapSweeper.Pool({
            pool: 0x287B0e934ed0439E2a7b1d5F0FC25eA2c24b64f7,
            fee: 300,       // 0.3%
            slippage: 10_0, // 10%
            partSize: 1_00  // 1 ether
        });

        router.setSweeper({
            _collection: 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984, // Uniswap
            _sweeper: requireDeployment('CowSwapSweeper'),
            _data: abi.encode(pools)
        });

        router.setSweeper({
            _collection: 0x27F2957b2205f417f6a4761Eac9E0920C6c9c3dc, // SappySeals
            _sweeper: requireDeployment('SudoswapSweeper'),
            _data: ''
        });

    }

}
