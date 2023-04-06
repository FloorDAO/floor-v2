// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {TickMath} from '@uniswap/v3-core/contracts/libraries/TickMath.sol';

import {UniswapAddLiquidity} from '@floor/actions/uniswap/AddLiquidity.sol';
import {UniswapClaimPoolRewards} from '@floor/actions/uniswap/ClaimPoolRewards.sol';
import {UniswapCreatePool} from '@floor/actions/uniswap/CreatePool.sol';
import {UniswapMintPosition} from '@floor/actions/uniswap/MintPosition.sol';
import {UniswapRemoveLiquidity} from '@floor/actions/uniswap/RemoveLiquidity.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract UniswapLiquidityTest is FloorTest, IERC721Receiver {

    /// The mainnet contract address of our Uniswap Position Manager
    address internal constant UNISWAP_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    uint24 internal constant POOL_FEE = 500;

    /// Two tokens that we can test with
    address internal constant TOKEN_A = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    address internal constant TOKEN_B = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH

    /// A user that holds sufficient liquidity of the above tokens
    address internal constant LIQUIDITY_HOLDER = 0x0f294726A2E3817529254F81e0C195b6cd0C834f;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_989_012;

    // Store our action contract
    UniswapAddLiquidity addLiquidityAction;
    UniswapClaimPoolRewards claimPoolRewardsAction;
    UniswapCreatePool createPoolAction;
    UniswapMintPosition mintPositionAction;
    UniswapRemoveLiquidity removeLiquidityAction;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our Uniswap actions
        addLiquidityAction = new UniswapAddLiquidity(UNISWAP_POSITION_MANAGER);
        claimPoolRewardsAction = new UniswapClaimPoolRewards(UNISWAP_POSITION_MANAGER);
        createPoolAction = new UniswapCreatePool(UNISWAP_POSITION_MANAGER);
        mintPositionAction = new UniswapMintPosition(UNISWAP_POSITION_MANAGER);
        removeLiquidityAction = new UniswapRemoveLiquidity(UNISWAP_POSITION_MANAGER);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH to the sender.
     */
    function test_CanCompleteLiquidityUserJourney() public {
        vm.startPrank(LIQUIDITY_HOLDER);

        // Create our pool
        uint poolAddress = createPoolAction.execute(
            abi.encode(
                TOKEN_A,  // token0
                TOKEN_B,  // token1
                POOL_FEE, // fee
                0         // sqrtPriceX96
            )
        );

        // Label our pool
        vm.label(address(uint160(poolAddress)), 'Uniswap Pool');

        // Approve our tokens to be used against the action contract
        ERC20(TOKEN_A).approve(address(mintPositionAction), 50 ether);
        ERC20(TOKEN_B).approve(address(mintPositionAction), 50 ether);

        // Confirm our liquidity holders starting balance
        assertEq(ERC20(TOKEN_A).balanceOf(address(LIQUIDITY_HOLDER)), 4823_014551);
        assertEq(ERC20(TOKEN_B).balanceOf(address(LIQUIDITY_HOLDER)), 12876961342000000);

        // Mint a new position. This will mint the NFT to the sender, so this test contract will
        // need an `onERC721Received` callback function.
        uint tokenId = mintPositionAction.execute(
            abi.encode(
                /// @param token0 - address of the first token
                TOKEN_A,
                /// @param token1 - address of the second token
                TOKEN_B,
                /// @param fee - The fee of the pool
                POOL_FEE,

                /**
                 * @dev Our tick values are hardcoded to end in a 0 as the tickSpacing calculation
                 * in the `flipTick` function of `TickBitmap.sol` was requiring the value to be a
                 * multiple of 10. I don't quite understand the reasoning of this.
                 */

                /// @param tickLower
                -887270,
                /// @param tickUpper
                887270,
                /// @param amount0Desired - The desired amount of token0 that should be supplied,
                10000000,
                /// @param amount1Desired - The desired amount of token1 that should be supplied,
                0.005 ether,
                /// @param amount0Min - The minimum amount of token0 that should be supplied,
                0,
                /// @param amount1Min - The minimum amount of token1 that should be supplied,
                0,
                /// @param deadline - The time by which the transaction must be included to effect the change
                block.timestamp
            )
        );

        // Since we are on a frozen block we can determine the token ID generated
        assertEq(tokenId, 483377);

        // The token should be owned by the sender of the contract
        assertEq(ERC721(UNISWAP_POSITION_MANAGER).ownerOf(tokenId), LIQUIDITY_HOLDER);

        // Confirm our liquidity holders balance after creating the ERC721 and providing the
        // initial liquidity.
        assertEq(ERC20(TOKEN_A).balanceOf(address(LIQUIDITY_HOLDER)), 4813_676208);
        assertEq(ERC20(TOKEN_B).balanceOf(address(LIQUIDITY_HOLDER)), 7876961342013941);

        // Approve our tokens to be used against the action contract
        ERC20(TOKEN_A).approve(address(addLiquidityAction), 50 ether);
        ERC20(TOKEN_B).approve(address(addLiquidityAction), 50 ether);

        // Add liquidity
        ERC721(UNISWAP_POSITION_MANAGER).approve(address(addLiquidityAction), tokenId);
        uint liquidity = addLiquidityAction.execute(
            abi.encode(
                /// @param tokenId - The ID of the token for which liquidity is being increased
                tokenId,
                /// @param token0 - address of the first token
                TOKEN_A,
                /// @param token1 - address of the second token
                TOKEN_B,
                /// @param amount0Desired - The desired amount of token0 that should be supplied,
                10000000,
                /// @param amount1Desired - The desired amount of token1 that should be supplied,
                0.005 ether,
                /// @param amount0Min - The minimum amount of token0 that should be supplied,
                0,
                /// @param amount1Min - The minimum amount of token1 that should be supplied,
                0,
                /// @param deadline - The time by which the transaction must be included to effect the change
                block.timestamp
            )
        );

        // Confirm the amount of liquidity received
        assertEq(liquidity, 216082647802);

        // Confirm our liquidity holders balance after providing additional liquidity
        assertEq(ERC20(TOKEN_A).balanceOf(address(LIQUIDITY_HOLDER)), 4804337865);
        assertEq(ERC20(TOKEN_B).balanceOf(address(LIQUIDITY_HOLDER)), 2876961342027882);

        // Partially remove liquidity
        ERC721(UNISWAP_POSITION_MANAGER).approve(address(removeLiquidityAction), tokenId);
        removeLiquidityAction.execute(
            abi.encode(
                tokenId,                // tokenId
                liquidity,              // liquidity
                0,                      // amount0Min
                0,                      // amount1Min
                block.timestamp         // deadline
            )
        );

        // Confirm our liquidity holders balance is the same after removing liquidity, as it will
        // only be updated after we run collect.
        assertEq(ERC20(TOKEN_A).balanceOf(address(LIQUIDITY_HOLDER)), 4804337865);
        assertEq(ERC20(TOKEN_B).balanceOf(address(LIQUIDITY_HOLDER)), 2876961342027882);

        // Claim pool rewards
        ERC721(UNISWAP_POSITION_MANAGER).approve(address(claimPoolRewardsAction), tokenId);
        claimPoolRewardsAction.execute(
            abi.encode(
                tokenId,           // tokenId
                type(uint128).max, // amount0
                type(uint128).max  // amount1
            )
        );

        // Confirm our liquidity holders balance after claiming rewards
        assertEq(ERC20(TOKEN_A).balanceOf(address(LIQUIDITY_HOLDER)), 4813676207);
        assertEq(ERC20(TOKEN_B).balanceOf(address(LIQUIDITY_HOLDER)), 7876961342013940);

        vm.stopPrank();
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

}
