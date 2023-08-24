// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
 */
contract DeployCoreContracts is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        address floor = requireDeployment('FloorToken');
        address treasury = requireDeployment('Treasury');

        // Deploy our pricing executor, powered by Uniswap
        UniswapV3PricingExecutor pricingExecutor = new UniswapV3PricingExecutor(0x1F98431c8aD98523631AE4a59f267346ea31F984, WETH);
        storeDeployment('UniswapV3PricingExecutor', address(pricingExecutor));

        // Deploy our veFloor staking contracts
        storeDeployment('VeFloorStaking', address(new VeFloorStaking(IERC20(floor), treasury)));
    }
}
