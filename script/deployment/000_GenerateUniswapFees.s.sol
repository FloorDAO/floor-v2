// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {IUniversalRouter} from '@floor-interfaces/uniswap/IUniversalRouter.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


contract GenerateUniswapFees is DeploymentScript {

    function run() external deployer {

        FLOOR floor = FLOOR(0xfEff35011D41F1d60655a008405D3FA851C29822);

        /// The interface of the Uniswap Universal Router
        IUniversalRouter universalRouter = IUniversalRouter(0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD);

        // Transfer the specified amount of token0 to the universal router from the sender
        IWETH(DEPLOYMENT_WETH).deposit{value: 1 ether}();
        IWETH(DEPLOYMENT_WETH).transfer(address(universalRouter), 1 ether);

        // Set up our data input
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(msg.sender, 1 ether, 0, abi.encodePacked(DEPLOYMENT_WETH, uint24(10000), address(floor)), false);

        // Sends the command to make a V3 token swap
        universalRouter.execute(abi.encodePacked(bytes1(uint8(0x80))), inputs, block.timestamp + 3600);

    }

}
