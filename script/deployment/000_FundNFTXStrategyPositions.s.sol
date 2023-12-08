// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';
import {NFTXV3Strategy} from '@floor/strategies/NFTXV3Strategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract FundNFTXStrategyPositions is DeploymentScript {

    // Milady: 6.402 MILADY vToken || 8 MILADY NFT
    // Pudgy: 6.328 PUDGY vToken || 3 PUDGY NFT

    function run() external deployer {

        NFTXV3LiquidityStrategy liquidityStrategy = NFTXV3LiquidityStrategy(payable(0x00827e97e2A224Fb3553Ab703056B71961552334));
        NFTXV3Strategy inventoryStrategy = NFTXV3Strategy(payable(0x4b7F3eb67598C3080DEf955440c763d7C373F4Ea));

        console.log(liquidityStrategy.positionId());

        (address[] memory liquidityTokens, uint[] memory liquidityAmounts) = liquidityStrategy.available();
        (address[] memory inventoryTokens, uint[] memory inventoryAmounts) = inventoryStrategy.available();

        console.log(liquidityTokens[0]);
        console.log(liquidityAmounts[0]);
        console.log(liquidityTokens[1]);
        console.log(liquidityAmounts[1]);

        console.log(inventoryTokens[0]);
        console.log(inventoryAmounts[0]);  // 3859036705818636

        /*
        // MILADY LIQUIDITY
        NFTXV3LiquidityStrategy strategy = NFTXV3LiquidityStrategy(payable(0x00827e97e2A224Fb3553Ab703056B71961552334));
        strategy.vToken().approve(address(strategy), 2 ether);
        strategy.deposit{value: 10 ether}({
            vTokenDesired: 2 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 1 ether,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });
        */

        /*
        // PUDGY LIQUIDITY
        NFTXV3LiquidityStrategy strategy = NFTXV3LiquidityStrategy(payable(0x3e4f4846e40d1Fa27Bcc3276fFa56f214eA08597));
        strategy.vToken().approve(address(strategy), 3 ether);
        strategy.deposit{value: 20 ether}({
            vTokenDesired: 1.5 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 1 ether,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });
        */

        // MILADY INVENTORY
        // NFTXV3Strategy _strategy = NFTXV3Strategy(payable(0x4b7F3eb67598C3080DEf955440c763d7C373F4Ea));
        // _strategy.vToken().approve(address(_strategy), 3 ether);
        // _strategy.depositErc20(3 ether);
    }

}
