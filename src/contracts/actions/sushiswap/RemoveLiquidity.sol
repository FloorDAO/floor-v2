// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Action} from '@floor/actions/Action.sol';
import {IUniswapV2Factory} from '@floor-interfaces/uniswap/IUniswapV2Factory.sol';
import {IUniswapV2Router01} from '@floor-interfaces/uniswap/IUniswapV2Router01.sol';

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

/**
 * Allows liquidity to be removed from a Sushiswap position.
 */
contract SushiswapRemoveLiquidity is Action {
    using TokenUtils for address;

    struct ActionRequest {
        address tokenA;
        address tokenB;
        address to;
        uint liquidity;
        uint amountAMin;
        uint amountBMin;
        uint deadline;
    }

    /// WETH token address
    address internal constant WETH_TOKEN = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// Uniswap contract references
    IUniswapV2Router01 public immutable uniswapRouter;
    IUniswapV2Factory public immutable uniswapFactory;

    /**
     * Sets up our immutable Sushiswap contract references.
     *
     * @param _uniswapRouter The address of the external Uniswap router contract
     * @param _uniswapFactory The address of the external Uniswap factory contract
     */
    constructor(address _uniswapRouter, address _uniswapFactory) {
        uniswapRouter = IUniswapV2Router01(_uniswapRouter);
        uniswapFactory = IUniswapV2Factory(_uniswapFactory);
    }

    /**
     * Removes liquidity to the Sushiswap pool.
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
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

        // Emit our `ActionEvent`
        emit ActionEvent('SushiswapRemoveLiquidity', _request);

        return 0;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }
}
