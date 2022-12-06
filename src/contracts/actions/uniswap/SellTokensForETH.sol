// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';


contract UniSwapSellTokensForETH is BaseAction {

    /// ..
    ISwapRouter public immutable swapRouter;

    /// ..
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// ..
    address public immutable treasury;

    /**
     *
     */
    struct ActionRequest {
        address token0;
        uint24 fee;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint256 deadline;
    }

    /**
     *
     */
    struct ActionResponse {
        uint256 amountOut;
    }

    /**
     *
     */
    constructor (address _swapRouter, address _treasury) public {
        swapRouter = ISwapRouter(_swapRouter);
        treasury = _treasury;
    }

    /**
     * @notice swapExactInputSingle swaps a fixed amount of DAI for a maximum possible amount of WETH9
     * using the DAI/WETH9 0.3% pool by calling `exactInputSingle` in the swap router.
     *
     * @dev The calling address must approve this contract to spend at least `amountIn` worth of its
     * DAI for this function to succeed.
     *
     * @param amountIn The exact amount of DAI that will be swapped for WETH9.
     *
     * @return amountOut The amount of WETH9 received.
     */
    function execute(ActionRequest request) public returns (ActionResponse response) {
        // msg.sender must approve this contract

        // Transfer the specified amount of token0 to this contract.
        TransferHelper.safeTransferFrom(request.token0, treasury, address(this), request.amountIn);

        // Approve the router to spend DAI.
        TransferHelper.safeApprove(request.token0, address(swapRouter), request.amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: request.token0,
                tokenOut: WETH,
                fee: request.fee,
                recipient: treasury,
                deadline: request.deadline,
                amountIn: request.amountIn,
                amountOutMinimum: request.amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        return ActionResponse({
            amountOut: swapRouter.exactInputSingle(params)
        });
    }

}
