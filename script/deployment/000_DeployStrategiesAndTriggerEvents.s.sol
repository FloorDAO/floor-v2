// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from '../../test/mocks/erc/ERC1155Mock.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with strategies to create events.
 *
 * Triggered:
 *  - NFTXInventoryStakingStrategy
 *  - - deposit
 *  - - harvest
 *  - NFTXLiquidityPoolStakingStrategy
 *  - - deposit
 *  - - harvest
 *  - DistributedRevenueStakingStrategy
 *  - - deposit
 *  - - harvest
 *  - - withdraw
 *  - RevenueStakingStrategy
 *  - - deposit
 *  - - harvest
 *  - - withdraw
 */
contract DeployStrategiesAndTriggerEvents is DeploymentScript {

    // Define a valid collection we can mint and reference
    ERC721Mock VALID_COLLECTION = ERC721Mock(0xDc110028492D1baA15814fCE939318B6edA13098);

    // Our wallet
    address WALLET = 0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348;

    function run() external deployer {

        // Load and cast our Collection Registry to set up the collection as expected
        // CollectionRegistry(requireDeployment('CollectionRegistry')).approveCollection(
        //     address(VALID_COLLECTION),
        //     address(1)
        // );

        // Load our epoch manager
        address epochManager = requireDeployment('EpochManager');

        // Set up a mock erc20 that will be our
        ERC20Mock erc20Mock = ERC20Mock(0x01BfC453938bb28b4743ac5f181f189ACBA61610);
        // erc20Mock.mint(WALLET, 10000 ether);

        // Store our strategy variables
        uint strategyId;
        address strategy;

        // Register our strategy factory contract that will deploy each strategy
        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));

        // Set our Strategy Factory to send withdrawals to the WALLET, and not another contract. Though
        // first we want to cache the value so that we can reset it again later.
        address factoryTreasury = strategyFactory.treasury();
        strategyFactory.setTreasury(WALLET);

        // src/contracts/strategies/NFTXInventoryStakingStrategy.sol

        // (strategyId, strategy) = strategyFactory.deployStrategy(
        //     'NFTXInventory',
        //     requireDeployment('NFTXInventoryStakingStrategy'),
        //     abi.encode(
        //         69, // _vaultId
        //         0x05679E29385EEC643c91cdBDB9f31d8e1415c61f, // _underlyingToken
        //         0x5d17A434c9FCf90CBcB528e29E922d633F8FF635, // _yieldToken
        //         0x6e91A3f27cE6753f47C66B76B03E6A7bFdDB605B, // _inventoryStaking
        //         0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
        //         0x8B9D81fF1845375379865c0997bcFf538513Eae1 // _unstakingZap
        //     ),
        //     address(VALID_COLLECTION)
        // );

        /**
         * @dev The underlying token is the token that is taken. We need to get some of this
         * token before we run these tests. This can be done on the NFTX site. We need to get
         * a few underlying tokens and a few LP tokens.
         */

        // Deposit
        // IERC20(0x05679E29385EEC643c91cdBDB9f31d8e1415c61f).approve(strategy, 0.1 ether);
        // NFTXInventoryStakingStrategy(strategy).depositErc20(0.1 ether);

        // Harvest
        // strategyFactory.harvest(strategyId);

        // Withdraw
        // strategyFactory.withdraw(2, abi.encodeWithSelector(
        //     NFTXInventoryStakingStrategy(strategy).withdrawErc20.selector,
        //     0.1 ether
        // ));

        // src/contracts/strategies/NFTXLiquidityPoolStakingStrategy.sol

        // (strategyId, strategy) = strategyFactory.deployStrategy(
        //     'NFTXLiquidityPool',
        //     requireDeployment('NFTXLiquidityPoolStakingStrategy'),
        //     abi.encode(
        //         69, // _vaultId
        //         0xfe68945e076666ba1c98a059049D2f58A497E94a, // _underlyingToken     // MILADYWETH
        //         0x17BA821aE15deaB091edAAee38cAC1AACb9598Ff, // _yieldToken          // xMILADYWETH
        //         0x05679E29385EEC643c91cdBDB9f31d8e1415c61f, // _rewardToken         // MILADY
        //         0xAfC303423580239653aFB6fb06d37D666ea0f5cA, // _liquidityStaking
        //         0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
        //         WETH // _weth
        //     ),
        //     address(VALID_COLLECTION)
        // );

        // Deposit
        // IERC20(0xfe68945e076666ba1c98a059049D2f58A497E94a).approve(strategy, 0.1 ether);
        // NFTXLiquidityPoolStakingStrategy(strategy).depositErc20(0.1 ether);

        // Harvest
        // strategyFactory.harvest(strategyId);

        // Withdraw
        // strategyFactory.withdraw(3, abi.encodeWithSelector(
        //     NFTXLiquidityPoolStakingStrategy(strategy).withdrawErc20.selector,
        //     0.1 ether
        // ));

        // src/contracts/strategies/UniswapV3Strategy.sol

        // (strategyId, strategy) = strategyFactory.deployStrategy(
        //     'UniswapV3',
        //     requireDeployment('UniswapV3Strategy'),
        //     abi.encode(
        //         address(erc20Mock), // address token0
        //         WETH,       // address token1
        //         500,        // uint24 fee
        //         92527072418752397425999, // uint96 sqrtPriceX96
        //         -887270,    // int24 tickLower
        //         887270,     // int24 tickUpper
        //         address(0), // address pool
        //         0xC36442b4a4522E871399CD717aBDD847Ab11FE88 // address positionManager
        //     ),
        //     address(VALID_COLLECTION)
        // );

        // // Deposit
        // erc20Mock.approve(strategy, 1 ether);

        // IWETH(WETH).deposit{value: 1 ether}();
        // IWETH(WETH).approve(strategy, 1 ether);

        // (uint liquidity,,) = UniswapV3Strategy(strategy).deposit(1 ether, 1 ether, 0, 0, block.timestamp + 60);

        // Harvest
        // strategyFactory.harvest(strategyId);

        // Withdraw
        strategy = 0xdc7CDc5c198ab2F904eC1B416E2dC7f0fBaC9F50;
        strategyFactory.withdraw(7, abi.encodeWithSelector(
            UniswapV3Strategy(strategy).withdraw.selector,
            0,
            0,
            block.timestamp + 60,
            11678558
        ));

        // src/contracts/strategies/DistributedRevenueStakingStrategy.sol

        // (strategyId, strategy) = strategyFactory.deployStrategy(
        //     'DistributedRevenue',
        //     requireDeployment('DistributedRevenueStakingStrategy'),
        //     abi.encode(address(erc20Mock), 10 ether, epochManager),
        //     address(VALID_COLLECTION)
        // );

        // Deposit
        // erc20Mock.approve(strategy, 1 ether);
        // DistributedRevenueStakingStrategy(strategy).depositErc20(1 ether);

        // Harvest
        // strategyFactory.harvest(strategyId);

        // Withdraw
        // strategyFactory.withdraw(strategyId, abi.encodeWithSelector(
        //     DistributedRevenueStakingStrategy(strategy).withdrawErc20.selector
        // ));

        // src/contracts/strategies/RevenueStakingStrategy.sol

        // address[] memory tokens = new address[](1);
        // tokens[0] = address(erc20Mock);

        // (strategyId, strategy) = strategyFactory.deployStrategy(
        //    'RevenueStaking',
        //    requireDeployment('RevenueStakingStrategy'),
        //    abi.encode(tokens),
        //    address(VALID_COLLECTION)
        // );

        // Deposit
        // erc20Mock.approve(strategy, 1 ether);
        // RevenueStakingStrategy(strategy).depositErc20(address(erc20Mock), 1 ether);

        // Harvest
        // strategyFactory.harvest(strategyId);

        // Withdraw
        // strategyFactory.withdraw(strategyId, abi.encodeWithSelector(
        //     RevenueStakingStrategy(strategy).withdrawErc20.selector,
        //     address(erc20Mock),
        //     1 ether
        // ));

        // Reset the StrategyFactory treasury address
        strategyFactory.setTreasury(factoryTreasury);
    }

}
