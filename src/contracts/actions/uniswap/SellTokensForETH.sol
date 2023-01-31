// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISwapRouter} from '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {TransferHelper} from '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IAction} from '../../../interfaces/actions/Action.sol';

/**
 * This action allows us to use the UniSwap platform to perform a Single Swap.
 *
 * This will allow us to change an ERC20 in the {Treasury} to another, using dynamic
 * routing to accomplish this.
 *
 * https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps
 */
contract UniswapSellTokensForETH is IAction {
    /// The interface of the Uniswap router
    ISwapRouter public immutable swapRouter;

    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The {Treasury} contract that will provide the ERC20 tokens and will be
    /// the recipient of the swapped WETH.
    address public immutable treasury;

    /**
     * Store our required information to action a swap.
     *
     * @param token0 The contract address of the token being swapped
     * @param fee The fee tier of the pool, used to determine the correct pool
     * contract in which to execute the swap
     * @param amountIn The amount of the token actually spent in the swap
     * @param amountOutMinimum The minimum amount of WETH to receive. This helps
     * protect against getting an unusually bad price for a trade due to a front
     * running sandwich or another type of price manipulation
     * @param deadline The unix time after which a swap will fail, to protect
     * against long-pending transactions and wild swings in prices
     */
    struct ActionRequest {
        address token0;
        uint24 fee;
        uint amountIn;
        uint amountOutMinimum;
        uint deadline;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     *
     * @param _swapRouter The UniSwap {SwapRouter} contract
     * @param _treasury Address of the Floor {Treasury} contract
     */
    constructor(address _swapRouter, address _treasury) {
        swapRouter = ISwapRouter(_swapRouter);
        treasury = _treasury;
    }

    /**
     * Swaps a fixed amount of our `token0` for a maximum possible amount of WETH using the
     * USDC/WETH 0.05% pool, by calling `exactInputSingle` in the swap router.
     *
     * @dev The calling address must approve this contract to spend at least `amountIn` worth of its
     * `token0` for this function to succeed.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH generated by the execution
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Transfer the specified amount of token0 to this contract from the {Treasury}
        TransferHelper.safeTransferFrom(request.token0, treasury, address(this), request.amountIn);

        // Approve the router to spend the desired token
        TransferHelper.safeApprove(request.token0, address(swapRouter), request.amountIn);

        // Set up our swap parameters based on `execute` parameters
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams(
            request.token0, // tokenIn
            WETH, // tokenOut
            request.fee, // fee
            treasury, // recipient
            request.deadline, // deadline
            request.amountIn, // amountIn
            request.amountOutMinimum, // amountOutMinimum
            0 // sqrtPriceLimitX96
        );

        // The call to `exactInputSingle` executes the swap
        uint amountOut = swapRouter.exactInputSingle(params);

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury} during the swap itself.
        return amountOut;
    }
}
