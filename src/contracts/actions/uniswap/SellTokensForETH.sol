// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import '../../../interfaces/actions/Action.sol';


/**
 * https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps
 */
contract UniswapSellTokensForETH is IAction {

    /// The interface of the Uniswap router
    ISwapRouter public immutable swapRouter;

    /// Our WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The {Treasury} contract that will be the funder of the funds and
    /// the recipient of the swapped WETH.
    address public immutable treasury;

    /**
     * Store our required information to action a swap.
     */
    struct ActionRequest {
        address token0;
        uint24 fee;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint256 deadline;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     */
    constructor (address _swapRouter, address _treasury) {
        swapRouter = ISwapRouter(_swapRouter);
        treasury = _treasury;
    }

    /**
     * @notice swapExactInputSingle swaps a fixed amount of our `token0` for a maximum possible
     * amount of WETH using the USDC/WETH 0.05% pool, by calling `exactInputSingle` in the swap
     * router.
     *
     * @dev The calling address must approve this contract to spend at least `amountIn` worth of its
     * `token0` for this function to succeed.
     */
    function execute(bytes calldata _request) public returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Transfer the specified amount of token0 to this contract from the {Treasury}
        TransferHelper.safeTransferFrom(request.token0, treasury, address(this), request.amountIn);

        // Approve the router to spend the desired token
        TransferHelper.safeApprove(request.token0, address(swapRouter), request.amountIn);

        // Set up our swap parameters based on `execute` parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            request.token0,            // tokenIn
            WETH,                      // tokenOut
            request.fee,               // fee
            treasury,                  // recipient
            request.deadline,          // deadline
            request.amountIn,          // amountIn
            request.amountOutMinimum,  // amountOutMinimum
            0                          // sqrtPriceLimitX96
        );

        // The call to `exactInputSingle` executes the swap
        uint amountOut = swapRouter.exactInputSingle(params);

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury} during the swap itself.
        return amountOut;
    }

}
