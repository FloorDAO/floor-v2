// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IUniswapV2Factory} from '@floor-interfaces/uniswap/IUniswapV2Factory.sol';
import {IUniswapV2Router01} from '@floor-interfaces/uniswap/IUniswapV2Router01.sol';

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

/**
 * ..
 *
 * @author Twade
 */
contract SushiswapRemoveLiquidity is IAction, Ownable, Pausable {
    using TokenUtils for address;

    struct ActionRequest {
        address tokenA;
        address tokenB;
        uint liquidity;
        uint amountAMin;
        uint amountBMin;
        address to;
        uint deadline;
    }

    /// ..
    address internal constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// ..
    IUniswapV2Router01 uniswapRouter;

    /// ..
    IUniswapV2Factory uniswapFactory;

    /**
     * ..
     */
    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router01(_uniswapRouter);
        uniswapFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Get our LP token address
        address lpTokenAddr = uniswapFactory.getPair(request.tokenA, request.tokenB);

        // Pull our LP tokens from the requester if needed
        uint pulledTokens = lpTokenAddr.pullTokensIfNeeded(msg.sender, request.liquidity);

        // Allow the uniswap Router to handle the LP token(s)
        lpTokenAddr.approveToken(address(uniswapRouter), pulledTokens);

        // Update our liquidity value to match the number of tokens we were able to acquire
        request.liquidity = pulledTokens;

        uniswapRouter.removeLiquidity(
            request.tokenA, request.tokenB, request.liquidity, request.amountAMin, request.amountBMin, request.to, request.deadline
        );

        return 0;
    }

    /**
     * ..
     */
    receive() external payable {}
}
