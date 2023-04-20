// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {VoteMarket} from '@floor/bribes/VoteMarket.sol';
import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {NftStaking} from '@floor/staking/NftStaking.sol';
import {NftStakingBoostCalculator} from '@floor/staking/NftStakingBoostCalculator.sol';
import {NftStakingLocker} from '@floor/staking/NftStakingLocker.sol';
import {NftStakingNFTXV2} from '@floor/staking/NftStakingNFTXV2.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Deploys our treasury actions.
 */
contract DeployCoreContracts is DeploymentScript {

    function run() external deployer {

        // Confirm that we have our required contracts deployed
        address collectionRegistry = requireDeployment('CollectionRegistry');
        address floor = requireDeployment('Floor');
        address treasury = requireDeployment('Treasury');

        // Define our oracle wallet that will vote market bribe attributions
        address oracleWallet = address(1);

        // Deploy our bribe / vote market contract
        storeDeployment('VoteMarket', address(new VoteMarket(collectionRegistry, oracleWallet, treasury)));

        // Deploy our pricing executor, powered by Uniswap
        UniswapV3PricingExecutor pricingExecutor = new UniswapV3PricingExecutor(0x1F98431c8aD98523631AE4a59f267346ea31F984, floor);
        storeDeployment('UniswapV3PricingExecutor', address(pricingExecutor));

        // Deploy our staking contracts
        NftStaking nftStaking = new NftStaking(address(pricingExecutor), uint16(8000));
        storeDeployment('NftStaking', address(nftStaking));

        storeDeployment('NftStakingBoostCalculator', address(new NftStakingBoostCalculator()));
        storeDeployment('NftStakingLocker', address(new NftStakingLocker(address(nftStaking))));
        storeDeployment('NftStakingNFTXV2', address(new NftStakingNFTXV2(address(nftStaking))));

        // Deploy our veFloor staking contracts
        storeDeployment('VeFloorStaking', address(new VeFloorStaking(IERC20(floor), treasury)));

    }

}
