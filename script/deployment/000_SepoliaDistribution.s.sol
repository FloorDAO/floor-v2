// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FLOOR} from '@floor/tokens/Floor.sol';
import {WrapEth} from '@floor/actions/utils/WrapEth.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';
import {Treasury} from '@floor/Treasury.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract SepoliaDistribution is DeploymentScript {

    function run() external deployer {

        FLOOR floor = FLOOR(requireDeployment('FloorToken'));

        // Send FLOOR to these addresses
        floor.mint(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, 20000 ether);
        floor.mint(0x0f294726A2E3817529254F81e0C195b6cd0C834f, 10000 ether);
        floor.mint(0x329393e440fD67ba84296a6D64DE42eE79DdD0Bd, 15000 ether);
        floor.mint(0x84f4840E47199F1090cEB108f74C5F332219539A, 25000 ether);
        floor.mint(0x51200AA490F8DF9EBdC9671cF8C8F8A12c089fDa, 20000 ether);

        // Send sepolia gas to addresses
        payable(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96).call{value: 0.025 ether}('');
        payable(0x0f294726A2E3817529254F81e0C195b6cd0C834f).call{value: 0.025 ether}('');
        payable(0x329393e440fD67ba84296a6D64DE42eE79DdD0Bd).call{value: 0.025 ether}('');
        payable(0x84f4840E47199F1090cEB108f74C5F332219539A).call{value: 0.025 ether}('');
        payable(0x51200AA490F8DF9EBdC9671cF8C8F8A12c089fDa).call{value: 0.025 ether}('');

    }

}
