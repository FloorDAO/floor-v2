// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BuyTokensWithTokens} from '@floor/actions/0x/BuyTokensWithTokens.sol';
import {CowSwapCreateOrder} from '@floor/actions/cowswap/CreateOrder.sol';
import {GemSweep} from '@floor/actions/gem/Sweep.sol';
import {LlamapayCreateStream} from '@floor/actions/llamapay/CreateStream.sol';
import {LlamapayDeposit} from '@floor/actions/llamapay/Deposit.sol';
import {LlamapayRouter} from '@floor/actions/llamapay/LlamapayRouter.sol';
import {LlamapayWithdraw} from '@floor/actions/llamapay/Withdraw.sol';
import {NFTXSellNftsForEth} from '@floor/actions/nftx/SellNftsForEth.sol';
import {SushiswapAddLiquidity} from '@floor/actions/sushiswap/AddLiquidity.sol';
import {SushiswapRemoveLiquidity} from '@floor/actions/sushiswap/RemoveLiquidity.sol';
import {CowSwapSweeper} from '@floor/sweepers/CowSwap.sol';
import {GemSweeper} from '@floor/sweepers/Gem.sol';
import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {UniswapAddLiquidity} from '@floor/actions/uniswap/AddLiquidity.sol';
import {UniswapClaimPoolRewards} from '@floor/actions/uniswap/ClaimPoolRewards.sol';
import {UniswapCreatePool} from '@floor/actions/uniswap/CreatePool.sol';
import {UniswapMintPosition} from '@floor/actions/uniswap/MintPosition.sol';
import {UniswapRemoveLiquidity} from '@floor/actions/uniswap/RemoveLiquidity.sol';
import {UniswapSellTokensForETH} from '@floor/actions/uniswap/SellTokensForETH.sol';
import {RawTx} from '@floor/actions/utils/RawTx.sol';
import {SendEth} from '@floor/actions/utils/SendEth.sol';
import {UnwrapWeth} from '@floor/actions/utils/UnwrapWeth.sol';
import {WrapEth} from '@floor/actions/utils/WrapEth.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our treasury actions.
 */
contract DeployTreasuryActions is DeploymentScript {
    function run() external deployer {
        // Confirm that we have our required contracts deployed
        address treasury = requireDeployment('Treasury');

        // Set up some live uniswap contracts
        address uniswapPositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

        // Gem actions
        GemSweep gemSweep = new GemSweep();
        gemSweep.setGemSwap(0x83C8F28c26bF6aaca652Df1DbBE0e1b56F8baBa2);

        // Llamapay helper contract and actions
        LlamapayRouter llamapayRouter = new LlamapayRouter(0xde1C04855c2828431ba637675B6929A684f84C7F);

        // Store our created action contract addresses
        storeDeployment('BuyTokensWithTokens', address(new BuyTokensWithTokens(0xDef1C0ded9bec7F1a1670819833240f027b25EfF)));
        storeDeployment('GemSweep', address(gemSweep));
        storeDeployment('LlamapayRouter', address(llamapayRouter));
        storeDeployment('LlamapayCreateStream', address(new LlamapayCreateStream(llamapayRouter)));
        storeDeployment('LlamapayDeposit', address(new LlamapayDeposit(llamapayRouter)));
        storeDeployment('LlamapayWithdraw', address(new LlamapayWithdraw(llamapayRouter)));
        storeDeployment('NFTXSellNftsForEth', address(new NFTXSellNftsForEth(0x941A6d105802CCCaa06DE58a13a6F49ebDCD481C)));
        storeDeployment('SushiswapAddLiquidity', address(new SushiswapAddLiquidity(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F)));
        storeDeployment(
            'SushiswapRemoveLiquidity',
            address(new SushiswapRemoveLiquidity(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F, 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac))
        );

        storeDeployment('CowSwapCreateOrder', address(new CowSwapCreateOrder(0x9008D19f58AAbD9eD0D60971565AA8510560ab41, WETH)));
        storeDeployment('CowSwapSweeper', address(new CowSwapSweeper(0x9008D19f58AAbD9eD0D60971565AA8510560ab41, treasury, WETH)));
        storeDeployment('GemSweeper', address(new GemSweeper()));
        storeDeployment('ManualSweeper', address(new ManualSweeper()));

        storeDeployment('UniswapAddLiquidity', address(new UniswapAddLiquidity(uniswapPositionManager)));
        storeDeployment('UniswapClaimPoolRewards', address(new UniswapClaimPoolRewards(uniswapPositionManager)));
        storeDeployment('UniswapCreatePool', address(new UniswapCreatePool(uniswapPositionManager)));
        storeDeployment('UniswapMintPosition', address(new UniswapMintPosition(uniswapPositionManager)));
        storeDeployment('UniswapRemoveLiquidity', address(new UniswapRemoveLiquidity(uniswapPositionManager)));
        storeDeployment('UniswapSellTokensForETH', address(new UniswapSellTokensForETH(0xE592427A0AEce92De3Edee1F18E0157C05861564, WETH)));
        storeDeployment('RawTx', address(new RawTx()));
        storeDeployment('SendEth', address(new SendEth()));
        storeDeployment('UnwrapWeth', address(new UnwrapWeth(WETH)));
        storeDeployment('WrapEth', address(new WrapEth(WETH)));
    }
}
