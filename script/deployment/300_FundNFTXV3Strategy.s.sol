// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract FundNFTXV3Strategy is DeploymentScript {

    address WALLET = 0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348;

    function run() external deployer {

        // PUDGY LIQUIDITY
        NFTXV3LiquidityStrategy strategy = NFTXV3LiquidityStrategy(payable(0x2be7ee2f6a925426A3F209277595e6C32B136484));

        strategy.vToken().approve(address(strategy), type(uint).max);

        strategy.deposit{value: 5 ether}({
            vTokenDesired: strategy.vToken().balanceOf(address(WALLET)),
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });

    }

}
