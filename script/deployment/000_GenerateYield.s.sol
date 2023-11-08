// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {NFTXLiquidityPoolStakingStrategy} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {Treasury} from '@floor/Treasury.sol';

import {IStrategyRegistry} from '@floor-interfaces/strategies/StrategyRegistry.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 *
 * 0xDc110028492D1baA15814fCE939318B6edA13098
 * 0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018
 * 0x572567C9aC029bd617CdBCF43b8dcC004A3D1339
 *
 */
contract GenerateYield is DeploymentScript {

    uint TOKEN_START = 540;

    function run() external deployer {

        // Deploy new strategies
        StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));

        // Reference our NFTX strategies
        (,address _strategy) = strategyFactory.deployStrategy(
            'NFTX Mocker Inventory Strategy',
            requireDeployment('NFTXInventoryStakingStrategy'),
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
            requireDeployment('NFTXLiquidityPoolStakingStrategy'),
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
        for (uint i = TOKEN_START; i < TOKEN_START + 30; ++i) {
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
            inventoryTokenIds[i] = TOKEN_START + 10 + i;

            inventoryApprovals[i] = ITreasury.ActionApproval({
                _type: TreasuryEnums.ApprovalType.ERC721,
                assetContract: address(erc721),
                target: address(inventoryStaking),
                tokenId: TOKEN_START + 10 + i,
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
            assetContract: 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6, // WETH
            target: address(liquidityStaking),
            tokenId: 0,
            amount: 20 ether
        });

        // Create position with 721s + ETH into NFTX LP strategy
        uint[] memory liquidityTokenIds = new uint[](10);
        for (uint i; i < 10; ++i) {
            liquidityTokenIds[i] = TOKEN_START + i;

            approvals[i + 1] = ITreasury.ActionApproval({
                _type: TreasuryEnums.ApprovalType.ERC721,
                assetContract: address(erc721),
                target: address(liquidityStaking),
                tokenId: TOKEN_START + i,
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
