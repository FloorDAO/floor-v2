// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {Action} from '@floor/actions/Action.sol';
import {IUniswapV2Router01} from '@floor-interfaces/uniswap/IUniswapV2Router01.sol';

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

/**
 * Allows liquidity to be added to a Sushiswap position.
 */
contract SushiswapAddLiquidity is Action {
    using TokenUtils for address;

    struct ActionRequest {
        address tokenA;
        address tokenB;
        address to;
        uint amountADesired;
        uint amountBDesired;
        uint amountAMin;
        uint amountBMin;
        uint deadline;
    }

    /// ETH token address
    address internal constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// Uniswap contract references
    IUniswapV2Router01 public immutable uniswapRouter;

    /**
     * Sets up our immutable Sushiswap contract references.
     *
     * @param _uniswapRouter The address of the external Uniswap router contract
     */
    constructor(address _uniswapRouter) {
        uniswapRouter = IUniswapV2Router01(_uniswapRouter);
    }

    /**
     * Adds liquidity to the Sushiswap pool, with logic varying if one of the tokens
     * is specified to be ETH, rather than an ERC20.
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Emit our `ActionEvent`
        emit ActionEvent('SushiswapAddLiquidity', _request);

        // Check if a requested token is ETH
        if (request.tokenA == ETH_TOKEN || request.tokenB == ETH_TOKEN) {
            require(request.tokenA != ETH_TOKEN, 'ETH token must be token B');
            return _addEthLiquidity(request);
        }

        return _addTokenLiquidity(request);
    }

    function _addEthLiquidity(ActionRequest memory request) internal returns (uint) {
        // Fetch tokens from address
        uint amountAPulled = request.tokenA.pullTokensIfNeeded(msg.sender, request.amountADesired);

        // Approve uniswapRouter so it can pull tokens
        request.tokenA.approveToken(address(uniswapRouter), amountAPulled);

        // Update our desired amounts based on the amount pulled
        request.amountADesired = amountAPulled;

        (uint amountA,, uint liquidity) = uniswapRouter.addLiquidityETH{value: msg.value}(
            request.tokenA, request.amountADesired, request.amountAMin, request.amountBMin, request.to, request.deadline
        );

        // Send leftovers
        request.tokenA.withdrawTokens(msg.sender, request.amountADesired - amountA);

        // Return any left over eth dust
        if (payable(address(this)).balance != 0) {
            (bool sent,) = msg.sender.call{value: payable(address(this)).balance}('');
            require(sent, 'Failed to refund Ether dust');
        }

        return liquidity;
    }

    function _addTokenLiquidity(ActionRequest memory request) internal returns (uint) {
        // Fetch tokens from address
        uint amountAPulled = request.tokenA.pullTokensIfNeeded(msg.sender, request.amountADesired);
        uint amountBPulled = request.tokenB.pullTokensIfNeeded(msg.sender, request.amountBDesired);

        // Approve uniswapRouter so it can pull tokens
        request.tokenA.approveToken(address(uniswapRouter), amountAPulled);
        request.tokenB.approveToken(address(uniswapRouter), amountBPulled);

        // Update our desired amounts based on the amount pulled
        request.amountADesired = amountAPulled;
        request.amountBDesired = amountBPulled;

        (uint amountA, uint amountB, uint liquidity) = uniswapRouter.addLiquidity(
            request.tokenA,
            request.tokenB,
            request.amountADesired,
            request.amountBDesired,
            request.amountAMin,
            request.amountBMin,
            request.to,
            request.deadline
        );

        // Send leftovers
        request.tokenA.withdrawTokens(msg.sender, request.amountADesired - amountA);
        request.tokenB.withdrawTokens(msg.sender, request.amountBDesired - amountB);

        return liquidity;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    /**
     * Allows the contract to receive ETH as an intermediary.
     */
    receive() external payable {}
}
