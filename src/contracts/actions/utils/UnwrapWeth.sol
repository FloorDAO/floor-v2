// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Action} from '@floor/actions/Action.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * This action allows us to unwrap WETH in the {Treasury} into ETH.
 */
contract UnwrapWeth is Action {
    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * Store our required information to action a swap.
     *
     * @param amount The amount of WETH to unwrap into ETH
     */
    struct ActionRequest {
        uint amount;
    }

    /**
     * Unwraps a fixed amount of WETH into ETH.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH unwrapped from the WETH by the execution
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Transfer the WETH from the sender into the action
        IWETH(WETH).transferFrom(msg.sender, address(this), request.amount);

        // Unwrap the WETH into ETH
        IWETH(WETH).withdraw(request.amount);

        // Transfer ETH to the caller
        (bool success,) = payable(msg.sender).call{value: request.amount}('');
        require(success, 'Eth send fail');

        // Emit our `ActionEvent`
        emit ActionEvent('UtilsUnwrapWeth', _request);

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury}.
        return request.amount;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    /**
     * To receive ETH from the WETH's withdraw function (it won't work without it).
     */
    receive() external payable {}
}
