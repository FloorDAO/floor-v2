// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {RawTx} from '@floor/actions/utils/RawTx.sol';
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {Treasury} from '@floor/Treasury.sol';
import {BaseStrategy} from '@floor/strategies/BaseStrategy.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 *
 *

 * 0xDc110028492D1baA15814fCE939318B6edA13098
 * 0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018
 * 0x572567C9aC029bd617CdBCF43b8dcC004A3D1339

  0x1dF8484C675c9AbCf3bB9204D5825Ff661824025
  Liquidation Pool
  0x4Ba3648a5E00D03Cc5482b274baaf32d79f92bdE
  Mock Strategy
  0x5271af5c9FEFFD22df3F34ce72Aaf913D20d28D9
  NFTXInventory
  0x4b7379FA0aED2906558098539F09cfE22109D59b
  NFTXLiquidityPool
  0x2Fd9f67192e0B53BeF36c76242A9fC73B5496FeA
  DistributedRevenue
  0x5950742154AF65E907D9566Aef7bDcdfF1e9Cac0
  RevenueStaking
  0xfE5a2647B70690A928240d9c92B82114B6Dd9e5D
  UniswapV3
  0xC308054dD185342F9717bDb4b37A8EcEcDA099E8
  UniswapV3
  0x0090160D43C8894e0Fdf23dE5A91104B61d06016
  Liquidation Pool

 *
 */
contract GenerateYield is DeploymentScript {

    // Our wallet
    address WALLET = 0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348;

    function run() external deployer {

        // Deploy new strategies
        StrategyFactory strategyFactory = StrategyFactory(0xdc7CDc5c198ab2F904eC1B416E2dC7f0fBaC9F50);

        // Reference our NFTX strategies
        (,address _strategy) = strategyFactory.deployStrategy(
            'NFTX Mocker Inventory Strategy',
            0x41a13e5c9686b6963DfB1E2E6cDf36c25232f725,
            abi.encode(
                69, // _vaultId
                0x05679E29385EEC643c91cdBDB9f31d8e1415c61f, // _vToken
                0x5d17A434c9FCf90CBcB528e29E922d633F8FF635, // _xToken
                0x6e91A3f27cE6753f47C66B76B03E6A7bFdDB605B, // _inventoryStaking
                0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
                0x8B9D81fF1845375379865c0997bcFf538513Eae1 // _unstakingZap
            ),
            0xDc110028492D1baA15814fCE939318B6edA13098
        );

        NFTXInventoryStakingStrategy inventoryStaking = NFTXInventoryStakingStrategy(_strategy);

        (, _strategy) = strategyFactory.deployStrategy(
            'NFTX Mocker Liquidity Strategy',
            0x62758A9C45dA5Fb9A0F8d088FceE96C0a47ca36d,
            abi.encode(
                69, // _vaultId
                0xfe68945e076666ba1c98a059049D2f58A497E94a, // _underlyingToken     // MOCKERWETH
                0x17BA821aE15deaB091edAAee38cAC1AACb9598Ff, // _yieldToken          // xMOCKERWETH
                0x05679E29385EEC643c91cdBDB9f31d8e1415c61f, // _rewardToken         // MOCKER
                0xAfC303423580239653aFB6fb06d37D666ea0f5cA, // _liquidityStaking
                0x775e23b64610dA2806dc5ed3b0862955e122DDc6, // _stakingZap
                WETH // _weth
            ),
            0xDc110028492D1baA15814fCE939318B6edA13098
        );
        NFTXLiquidityPoolStakingStrategy liquidityStaking = NFTXLiquidityPoolStakingStrategy(_strategy);

        // Reference our {Treasury} contract
        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Reference our {ERC721Mock} contract
        ERC721Mock erc721 = ERC721Mock(0xDc110028492D1baA15814fCE939318B6edA13098);

        // Mint ERC721s into the {Treasury}
        for (uint i = 500; i < 530; ++i) {
            erc721.mint(address(treasury), i);
        }

        // Deposit ETH + WETH into the {Treasury}
        (bool sent,) = address(treasury).call{value: 20 ether}('');
        require(sent, 'Failed to fund Treasury');

        // Wrap some WETH and send it to the {Treasury}
        IWETH(WETH).deposit{value: 20 ether}();
        IWETH(WETH).transfer(address(treasury), 20 ether);

        // Put 5 721s into an NFTX Inventory strategy
        ITreasury.ActionApproval[] memory inventoryApprovals = new ITreasury.ActionApproval[](5);
        uint[] memory inventoryTokenIds = new uint[](5);

        for (uint i; i < 5; ++i) {
            inventoryTokenIds[i] = 510 + i;

            inventoryApprovals[i] = ITreasury.ActionApproval({
                _type: TreasuryEnums.ApprovalType.ERC721,
                assetContract: address(erc721),
                target: address(inventoryStaking),
                tokenId: 510 + i,
                amount: 0
            });
        }

        treasury.strategyDeposit(
            inventoryStaking.strategyId(),
            abi.encodeWithSelector(NFTXInventoryStakingStrategy.depositErc721.selector, inventoryTokenIds),
            inventoryApprovals
        );

        // Set up approvals for ETH and 10 ERC721s
        ITreasury.ActionApproval[] memory approvals = new ITreasury.ActionApproval[](11);

        // Just pass ETH requirement
        approvals[0] = ITreasury.ActionApproval({
            _type: TreasuryEnums.ApprovalType.ERC20,
            assetContract: 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6,
            target: address(liquidityStaking),
            tokenId: 0,
            amount: 20 ether
        });

        // Create position with 721s + ETH into NFTX LP strategy
        uint[] memory liquidityTokenIds = new uint[](10);
        for (uint i; i < 10; ++i) {
            liquidityTokenIds[i] = 500 + i;

            approvals[i + 1] = ITreasury.ActionApproval({
                _type: TreasuryEnums.ApprovalType.ERC721,
                assetContract: address(erc721),
                target: address(liquidityStaking),
                tokenId: 500 + i,
                amount: 0
            });
        }

        treasury.strategyDeposit(
            liquidityStaking.strategyId(),
            abi.encodeWithSelector(NFTXLiquidityPoolStakingStrategy.depositErc721.selector, liquidityTokenIds, uint(0), 10 ether),
            approvals
        );

        // Caps will do some things on chain and after that is done we then get yield

    }

}
