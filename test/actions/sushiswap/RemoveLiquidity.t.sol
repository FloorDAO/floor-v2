// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {SushiswapAddLiquidity} from '@floor/actions/sushiswap/AddLiquidity.sol';
import {SushiswapRemoveLiquidity} from '@floor/actions/sushiswap/RemoveLiquidity.sol';
import {IWETH} from '../../../src/interfaces/tokens/WETH.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract SushiswapRemoveLiquidityTest is FloorTest {
    /// ..
    address internal constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant UNISWAP_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    /// ..
    address internal constant TOKEN_A = 0x1E4EDE388cbc9F4b5c79681B7f94d36a11ABEBC9;
    address internal constant TOKEN_B = 0x111111111117dC0aa78b770fA6A738034120C302;
    address internal constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_619_311;

    // Store our action contract
    SushiswapAddLiquidity addAction;
    SushiswapRemoveLiquidity action;

    // Store liquidity created in our `setUp` function
    uint tokenPosition;
    uint tokenEthPosition;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a floor migration contract
        addAction = new SushiswapAddLiquidity(UNISWAP_ROUTER);
        action = new SushiswapRemoveLiquidity(UNISWAP_ROUTER, UNISWAP_FACTORY);

        deal(TOKEN_A, address(this), 100 ether);
        deal(TOKEN_B, address(this), 100 ether);

        ERC20(TOKEN_A).approve(address(addAction), 50 ether);
        ERC20(TOKEN_B).approve(address(addAction), 50 ether);
    }

    /**
     * ..
     */
    function setUp() public {
        // Set up a liquidity placement so our user has something. This functionality is
        // already tested in another test suite so we can rely on it to work.
        tokenPosition = addAction.execute(abi.encode(TOKEN_A, TOKEN_B, address(this), 1 ether, 1 ether, 0, 0, block.timestamp + 3600));

        // Set up an ETH liquidity placement so our user has something. This functionality
        // is already tested in another test suite so we can rely on it to work. We can deposit
        // in ETH and it is automatically put into a WETH position.
        tokenEthPosition =
            addAction.execute{value: 1 ether}(abi.encode(TOKEN_A, ETH_TOKEN, address(this), 1 ether, 1 ether, 0, 0, block.timestamp + 3600));
    }

    /**
     * ..
     */
    function test_CanRemoveEthLiquidityAsTokenA() public {
        // A little bit of magic here, as we know the LP token generated for each of our
        // positions so we can ensure they are approved against the router before we make
        // calls to remove the liquidity.
        ERC20(0x6033368e4a402605294c91CF5c03d72bd96E7D8D).approve(address(action), type(uint).max);

        _removeLiquidity(TOKEN_A, WETH_TOKEN, tokenEthPosition);
    }

    /**
     * ..
     */
    function test_CanRemoveTokenLiquidity() external {
        // A little bit of magic here, as we know the LP token generated for each of our
        // positions so we can ensure they are approved against the router before we make
        // calls to remove the liquidity.
        ERC20(0x9ca4fD56be73dD79472aC686c2C582122d18C18F).approve(address(action), tokenPosition);

        _removeLiquidity(TOKEN_A, TOKEN_B, tokenPosition);
    }

    /**
     * ..
     */
    function _removeLiquidity(address tokenA, address tokenB, uint liquidity) internal returns (uint) {
        return action.execute(abi.encode(tokenA, tokenB, address(this), liquidity, 0, 0, block.timestamp + 3600));
    }

    receive() external payable {
        assertEq(msg.value, 999880756991001119);
    }
}
