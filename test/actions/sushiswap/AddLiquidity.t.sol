// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {SushiswapAddLiquidity} from '../../../src/contracts/actions/sushiswap/AddLiquidity.sol';
import {IWETH} from '../../../src/interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract SushiswapAddLiquidityTest is FloorTest {
    /// ..
    address internal constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /// ..
    address internal constant TOKEN_A = 0x1E4EDE388cbc9F4b5c79681B7f94d36a11ABEBC9; // X2Y2
    address internal constant TOKEN_B = 0x111111111117dC0aa78b770fA6A738034120C302; // 1Inch
    address internal constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_619_311;

    // Store our action contract
    SushiswapAddLiquidity action;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a floor migration contract
        action = new SushiswapAddLiquidity(UNISWAP_ROUTER);

        deal(TOKEN_A, address(this), 100 ether);
        deal(TOKEN_B, address(this), 100 ether);

        ERC20(TOKEN_A).approve(address(action), 50 ether);
        ERC20(TOKEN_B).approve(address(action), 50 ether);
    }

    /**
     * ..
     */
    function test_CanAddEthLiquidityAsTokenA() public {
        uint liquidity = _addLiquidity(TOKEN_A, ETH_TOKEN, 1 ether);
        assertEq(liquidity, 7824599337399158);
    }

    /**
     * ..
     */
    function test_CannotAddEthLiquidityAsTokenB() public {
        vm.expectRevert('ETH token must be token B');
        _addLiquidity(ETH_TOKEN, TOKEN_B, 1 ether);
    }

    /**
     * ..
     */
    function test_CanAddTokenLiquidity() external {
        uint liquidity = _addLiquidity(TOKEN_A, TOKEN_B, 0);

        // We should expect 10 ether, minus a `1000` fee
        assertEq(liquidity, 999999999999999000);
    }

    /**
     * ..
     */
    function _addLiquidity(address tokenA, address tokenB, uint msgValue) internal returns (uint) {
        return action.execute{value: msgValue}(
            abi.encode(
                tokenA, // address tokenA
                tokenB, // address tokenB
                1 ether, // uint amountADesired
                1 ether, // uint amountBDesired
                0, // uint amountAMin
                0, // uint amountBMin
                address(this), // address to
                block.timestamp + 3600 // uint deadline
            )
        );
    }

    /**
     * ..
     */
    receive() external payable {
        assertEq(msg.value, 999880756991001119);
    }
}
