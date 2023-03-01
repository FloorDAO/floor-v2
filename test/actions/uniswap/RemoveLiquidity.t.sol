// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {UniswapRemoveLiquidity} from '@floor/actions/uniswap/RemoveLiquidity.sol';
import {IWETH} from '../../../src/interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract UniswapRemoveLiquidityTest is FloorTest {
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
    UniswapRemoveLiquidity action;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a floor migration contract
        action = new UniswapRemoveLiquidity(UNISWAP_POSITION_MANAGER);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanAddLiquidity() public {
        vm.startPrank(LIQUIDITY_HOLDER);

        // Our action must be approved to use the liquidity ERC721
        IERC721(UNISWAP_POSITION_MANAGER).approve(address(action), 343765);

        // Action our trade
        uint liquidity = action.execute(
            abi.encode(
                /// @param tokenId - The ID of the token for which liquidity is being decreased
                343765,
                /// @param liquidity - The amount by which liquidity will be decreased,
                uint128(1 ether),
                /// @param amount0Min - The minimum amount of token0 that should be accounted for the burned liquidity,
                0,
                /// @param amount1Min - The minimum amount of token1 that should be accounted for the burned liquidity,
                0,
                /// @param deadline - The time by which the transaction must be included to effect the change
                block.timestamp + 3600,
                /// @param recipient - accounts to receive the tokens
                LIQUIDITY_HOLDER,
                /// @param amount0Max - The maximum amount of token0 to collect
                type(uint128).max,
                /// @param amount1Max - The maximum amount of token1 to collect
                type(uint128).max
            )
        );

        // Confirm our returned remaining liquidity
        assertEq(liquidity, 35890473089307141967);

        vm.stopPrank();
    }
}
