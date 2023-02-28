// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../../../src/contracts/actions/uniswap/AddLiquidity.sol';
import {IWETH} from '../../../src/interfaces/tokens/WETH.sol';

import '../../utilities/Environments.sol';

contract UniswapAddLiquidityTest is FloorTest {
    /// ..
    address internal constant UNISWAP_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    /// ..
    address internal constant TOKEN_A = 0x1E4EDE388cbc9F4b5c79681B7f94d36a11ABEBC9;
    address internal constant TOKEN_B = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// ..
    address internal constant LIQUIDITY_HOLDER = 0x0f294726A2E3817529254F81e0C195b6cd0C834f;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_619_311;

    // Store our action contract
    UniswapAddLiquidity action;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a floor migration contract
        action = new UniswapAddLiquidity(UNISWAP_POSITION_MANAGER);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanAddLiquidity() public {
        vm.startPrank(LIQUIDITY_HOLDER);

        // Deposit some of the holder's ETH into WETH
        IWETH(TOKEN_B).deposit{value: 0.05 ether}();

        // Approve our tokens to be used against the action contract
        ERC20(TOKEN_A).approve(address(action), 50 ether);
        ERC20(TOKEN_B).approve(address(action), 50 ether);

        // Action our trade
        uint liquidity = action.execute(
            abi.encode(
                /// @param tokenId - The ID of the token for which liquidity is being increased
                343765,
                /// @param amount0Desired - The desired amount of token0 that should be supplied,
                30.9534 ether,
                /// @param amount1Desired - The desired amount of token1 that should be supplied,
                0.05 ether,
                /// @param amount0Min - The minimum amount of token0 that should be supplied,
                0,
                /// @param amount1Min - The minimum amount of token1 that should be supplied,
                0,
                /// @param deadline - The time by which the transaction must be included to effect the change
                block.timestamp + 3600,
                /// @param from - account to take amounts from
                LIQUIDITY_HOLDER,
                /// @param token0 - address of the first token
                TOKEN_A,
                /// @param token1 - address of the second token
                TOKEN_B
            )
        );

        // Confirm our returned liquidity
        assertEq(liquidity, 9415764049564675849);

        vm.stopPrank();
    }
}
