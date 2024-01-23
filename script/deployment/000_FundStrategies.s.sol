// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from '../../test/mocks/erc/ERC1155Mock.sol';

import {WrapEth} from '@floor/actions/utils/WrapEth.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {DistributedRevenueStakingStrategy} from '@floor/strategies/DistributedRevenueStakingStrategy.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {RevenueStakingStrategy} from '@floor/strategies/RevenueStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';
import {Treasury} from '@floor/Treasury.sol';

import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract FundStrategies is DeploymentScript {

    function run() external deployer {

        // DOODLES (0.1 each) = 5.0
        // PUNKS (0.4 each) = 20.0
        // COOL CATS (0.05 each) = 2.5
        // TOTAL: 27.50

        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));
        address liquidityImplementation = requireDeployment('NFTXLiquidityPoolStakingStrategy');
        Treasury treasury = Treasury(requireDeployment('Treasury'));
        address payable wrapWth = requireDeployment('WrapEth');

        ITreasury.ActionApproval[] memory approvals = new ITreasury.ActionApproval[](1);
        approvals[0] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.NATIVE,
            assetContract: address(0),
            target: wrapWth,
            amount: 27.5 ether
        });

        // Wrap into WETH
        treasury.processAction(
            wrapWth,
            approvals,
            abi.encode(WrapEth.ActionRequest({
                amount: 27.5 ether
            })),
            0
        );

        (uint strategyId, address strategy) = strategyFactory.deployStrategy(
            'NFTX COOL CATS Liquidity',
            liquidityImplementation,
            abi.encode(
                78, // _vaultId
                0xb81FC95DdCc666Ad8F3131aB732332424A90C3a1, // _underlyingToken     // MILADYWETH
                0x01A7F6FD57baA06e731799cE17f8c6dFf89CACaB, // _yieldToken          // xMILADYWETH
                0xA0951BC039799cdA0f9A4df13c0fA206a680eA96, // _rewardToken         // MILADY
                0xAfC303423580239653aFB6fb06d37D666ea0f5cA, // _liquidityStaking
                0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
                DEPLOYMENT_WETH // _weth
            ),
            0x18F6CF0E62C438241943516C1ac880188304620C
        );

        uint[] memory tokenIds = new uint[](50);
        approvals = new ITreasury.ActionApproval[](2);

        uint index;
        for (uint i = 270; i <= 319; ++i) {
            tokenIds[index] = i;
            ++index;
        }


        approvals[0] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC721,
            assetContract: 0x18F6CF0E62C438241943516C1ac880188304620C,
            target: strategy,
            amount: 0
        });

        approvals[1] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC20,
            assetContract: DEPLOYMENT_WETH,
            target: strategy,
            amount: 2.5 ether
        });

        treasury.strategyDeposit(
            strategyId,
            abi.encodeWithSelector(
                NFTXLiquidityPoolStakingStrategy.depositErc721.selector,
                tokenIds, 2.5 ether, 2.5 ether
            ),
            approvals
        );

        console.log('NFTX COOL CATS Liquidity:');
        console.log(strategyId);
        console.log(strategy);
        console.log('---');

        (strategyId, strategy) = strategyFactory.deployStrategy(
            'NFTX CryptoPunk Liquidity',
            liquidityImplementation,
            abi.encode(
                77, // _vaultId
                0x785F8ddA687FdC7f24B58f6e6D8e9988f078eC79, // _underlyingToken     // MILADYWETH
                0xA02c83b0D8E6E3455F3a76FEb22d5D473C8eeFdD, // _yieldToken          // xMILADYWETH
                0xA8294Fa8065127AB27F483D4b0A70b4f77e5a072, // _rewardToken         // MILADY
                0xAfC303423580239653aFB6fb06d37D666ea0f5cA, // _liquidityStaking
                0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
                DEPLOYMENT_WETH // _weth
            ),
            0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7
        );

        tokenIds = new uint[](50);
        approvals = new ITreasury.ActionApproval[](2);

        index = 0;
        for (uint i = 281; i <= 330; ++i) {
            tokenIds[index] = i;
            ++index;
        }

        approvals[0] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC721,
            assetContract: 0xbB12Ad601d0024aE2cD6B763a823aD3E6A53e1e7,
            target: strategy,
            amount: 0
        });

        approvals[1] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC20,
            assetContract: DEPLOYMENT_WETH,
            target: strategy,
            amount: 20 ether
        });

        treasury.strategyDeposit(
            strategyId,
            abi.encodeWithSelector(
                NFTXLiquidityPoolStakingStrategy.depositErc721.selector,
                tokenIds, 20 ether, 20 ether
            ),
            approvals
        );

        console.log('NFTX CryptoPunk Liquidity:');
        console.log(strategyId);
        console.log(strategy);
        console.log('---');

        (strategyId, strategy) = strategyFactory.deployStrategy(
            'NFTX DOODLES Liquidity',
            liquidityImplementation,
            abi.encode(
                76, // _vaultId
                0xBa9c1E5bA25F48d6A1C054c3B616b614af87fc83, // _underlyingToken     // MILADYWETH     // _underlyingToken
                0xEE01624c1c56b2cEEbDE89D211FBF0b5F3D87472, // _yieldToken          // xMILADYWETH    // _dividendToken
                0x11801A32b1055Ff80dCCe28ED7269862e8B3E8Ee, // _rewardToken         // MILADY         // _rewardToken
                0xAfC303423580239653aFB6fb06d37D666ea0f5cA, // _liquidityStaking
                0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
                DEPLOYMENT_WETH // _weth
            ),
            0x056207f8Da23Ff08f1F410c1b6F4Bc7767229497
        );

        tokenIds = new uint[](50);
        approvals = new ITreasury.ActionApproval[](2);

        index = 0;
        for (uint i = 120; i <= 169; ++i) {
            tokenIds[index] = i;
            ++index;
        }

        approvals[0] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC721,
            assetContract: 0x056207f8Da23Ff08f1F410c1b6F4Bc7767229497,
            target: strategy,
            amount: 0
        });

        approvals[1] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC20,
            assetContract: DEPLOYMENT_WETH,
            target: strategy,
            amount: 5 ether
        });

        treasury.strategyDeposit(
            strategyId,
            abi.encodeWithSelector(
                NFTXLiquidityPoolStakingStrategy.depositErc721.selector,
                tokenIds, 5 ether, 5 ether
            ),
            approvals
        );

        console.log('NFTX DOODLES Liquidity:');
        console.log(strategyId);
        console.log(strategy);
        console.log('---');
    }

}
