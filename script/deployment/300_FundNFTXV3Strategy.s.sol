// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {NFTXV3Strategy} from '@floor/strategies/NFTXV3Strategy.sol';
import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract FundNFTXV3Strategy is DeploymentScript {

    address WALLET = 0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348;

    function run() external deployer {

        /*
        NFTXV3LiquidityStrategy strategy = NFTXV3LiquidityStrategy(payable(0xae60868aF7791eb1278a3482A42C9A6A975c369f));

        strategy.vToken().approve(address(strategy), type(uint).max);
        strategy.deposit{value: 10 ether}({
            vTokenDesired: 5 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });
        */

        /*
        NFTXV3Strategy strategy = NFTXV3Strategy(payable(0x9A1A42DEe50a182a11A280584f72d110a9862f3E));
        strategy.vToken().approve(address(strategy), type(uint).max);
        strategy.depositErc20(5 ether);
        */

    }

}
