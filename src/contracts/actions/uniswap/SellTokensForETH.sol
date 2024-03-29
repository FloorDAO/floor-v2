// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {TransferHelper} from '@uniswap-v3/v3-periphery/contracts/libraries/TransferHelper.sol';

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {Action} from '@floor/actions/Action.sol';

import {IPermit2} from '@floor-interfaces/uniswap/IPermit2.sol';
import {IUniversalRouter} from '@floor-interfaces/uniswap/IUniversalRouter.sol';

/**
 * This action allows us to use the UniSwap platform to perform a Single Swap.
 *
 * This will allow us to change an ERC20 in the {Treasury} to another, using dynamic
 * routing to accomplish this.
 *
 * https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps
 * https://docs.uniswap.org/contracts/universal-router/technical-reference
 */
contract UniswapSellTokensForETH is Action {
    /// The interface of the Uniswap Universal Router
    IUniversalRouter public immutable universalRouter;

    /// Mainnet WETH contract
    address public immutable WETH;

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
     * @param _universalRouter The UniSwap {UniversalRouter} contract
     */
    constructor(address _universalRouter, address _weth) {
        universalRouter = IUniversalRouter(_universalRouter);
        WETH = _weth;
    }

    /**
     * Swaps a fixed amount of our `token0` for a maximum possible amount of WETH.
     *
     * @dev The calling address must approve this contract to spend at least `amountIn` worth of its
     * `token0` for this function to succeed.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH generated by the execution
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Transfer the specified amount of token0 to the universal router from the sender
        TransferHelper.safeTransferFrom(request.token0, msg.sender, address(universalRouter), request.amountIn);

        // Set up our data input
        bytes[] memory inputs = new bytes[](1);
        inputs[0] =
            abi.encode(msg.sender, request.amountIn, request.amountOutMinimum, abi.encodePacked(request.token0, request.fee, WETH), false);

        // Sends the command to make a V3 token swap
        // @dev https://github.com/Uniswap/universal-router/blob/main/contracts/libraries/Commands.sol
        universalRouter.execute(abi.encodePacked(bytes1(uint8(0x80))), inputs, request.deadline);

        // Emit our `ActionEvent`
        emit ActionEvent('UniswapSellTokensForETH', _request);

        return 0;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }
}
