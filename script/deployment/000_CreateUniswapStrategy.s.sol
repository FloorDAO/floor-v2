// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TickMath} from '@uniswap-v3/v3-core/contracts/libraries/TickMath.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';
import {Treasury} from '@floor/Treasury.sol';

import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract CreateUniswapStrategy is DeploymentScript {

    function run() external deployer {

        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        address uniswapV3StrategyImplementation = requireDeployment('UniswapV3Strategy');
        FLOOR floor = FLOOR(requireDeployment('FloorToken'));
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('FLOOR/WETH UV3 Pool'),
            uniswapV3StrategyImplementation,
            abi.encode(
                address(floor), // address token0
                DEPLOYMENT_WETH, // address token1
                10000, // uint24 fee
                uint96(uint(2505290050365003892876723467)), // uint96 sqrtPriceX96
                -887200, // int24 tickLower
                887200, // int24 tickUpper
                0xc09D4849a695799FC5fD0022b0A740614c404063, // address pool
                // 0xC36442b4a4522E871399CD717aBDD847Ab11FE88 // address positionManager (mainnet)
                0x1238536071E1c677A632429e3655c799b22cDA52 // address positionManager (sepolia)
            ),
            DEPLOYMENT_WETH
        );

        floor.mint(address(treasury), 2000 ether);

        ITreasury.ActionApproval[] memory approvals = new ITreasury.ActionApproval[](2);
        approvals[0] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC20,
            assetContract: address(floor),
            target: _strategy,
            amount: 2000 ether
        });
        approvals[1] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC20,
            assetContract: DEPLOYMENT_WETH,
            target: _strategy,
            amount: 2 ether
        });

        treasury.strategyDeposit(
            _strategyId,
            abi.encodeWithSelector(
                UniswapV3Strategy.deposit.selector,
                2000 ether, 2 ether, 0, 0, block.timestamp + 3600
            ),
            approvals
        );
    }

}
