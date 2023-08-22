// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Action} from '@floor/actions/Action.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * This action allows us to wrap ETH in the {Treasury} into WETH.
 */
contract WrapEth is Action {
    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * Store our required information to action a swap.
     *
     * @param amount The amount of ETH to wrap into WETH
     */
    struct ActionRequest {
        uint amount;
    }

    /**
     * Wraps a fixed amount of ETH into WETH.
     *
     * @return uint The amount of ETH wrapped into WETH by the execution
     */
    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Ensure enough value was sent
        require(msg.value >= request.amount, 'Insufficient msg.value');

        // Deposit the requested amount into WETH
        IWETH(WETH).deposit{value: request.amount}();

        // Transfer all WETH from the contract back to the sender. This will help capture
        // any unaccounted for WETH (someone nice sent some?)
        IWETH(WETH).transfer(msg.sender, IWETH(WETH).balanceOf(address(this)));

        // Refund ETH to the caller
        uint remainingBalance = msg.value - request.amount;
        if (remainingBalance != 0) {
            (bool success,) = payable(msg.sender).call{value: remainingBalance}('');
            require(success, 'Eth send fail');
        }

        // Emit our `ActionEvent`
        emit ActionEvent('UtilsWrapEth', abi.encode(msg.value));

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the sender.
        return request.amount;
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    /**
     * Allow our contract to receive native tokens.
     */
    receive() external payable {
        // ..
    }
}
