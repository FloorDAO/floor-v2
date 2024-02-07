// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {CowSwapSweeper} from '@floor/sweepers/CowSwap.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract CowSwapSweeperTest is FloorTest {

    uint constant BLOCK_NUMBER = 19176494;

    CowSwapSweeper internal sweeper;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our sweeper contract
        sweeper = new CowSwapSweeper({
            _treasury: payable(0x3b91f74Ae890dc97bb83E7b8eDd36D8296902d68),
            _relayer: 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110,
            _composableCow: 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74,
            _twapHandler: 0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5
        });
    }

    function test_CanExecuteSweep() public {
        address[] memory collections = new address[](1);
        collections[0] = address(1);
        uint[] memory amounts = new uint[](1);
        amounts[0] = 1 ether;

        CowSwapSweeper.Pool[] memory pools = new CowSwapSweeper.Pool[](1);
        pools[0] = CowSwapSweeper.Pool({
            pool: 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640,   // Address of the UV3 pool
            fee: 300,          // The UV3 pool fee
            slippage: 10_0,    // % of slippage to 1dp accuracy
            partSize: 1_00     // The ETH size per part for fills (2dp)
        });

        sweeper.execute{value: 1 ether}({
            _collections: collections,
            _amounts: amounts,
            data: abi.encode(pools)
        });

        // Confirm that we now hold the expected balance in the pool
        assertEq(sweeper.weth().balanceOf(address(sweeper)), 1 ether);
    }

}
