// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {Treasury} from '@floor/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
 */
contract DeployCoreContracts is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        address floor = requireDeployment('FloorToken');
        address payable treasury = requireDeployment('Treasury');

        // Deploy our pricing executor, powered by Uniswap
        UniswapV3PricingExecutor pricingExecutor = new UniswapV3PricingExecutor(0xDD2dce9C403f93c10af1846543870D065419E70b, DEPLOYMENT_WETH);

        // Deploy our veFloor staking contracts
        address veFloorStaking = address(new VeFloorStaking(IERC20(floor), treasury));
        Treasury(treasury).setVeFloorStaking(veFloorStaking);

        storeDeployment('UniswapV3PricingExecutor', address(pricingExecutor));
        storeDeployment('VeFloorStaking', veFloorStaking);
    }
}
