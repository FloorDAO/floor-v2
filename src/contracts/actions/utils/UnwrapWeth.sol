// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IAction} from '../../../interfaces/actions/Action.sol';
import {IWETH} from '../../../interfaces/tokens/WETH.sol';

/**
 * This action allows us to unwrap WETH in the {Treasury} into ETH.
 */
contract UnwrapWeth is IAction {
    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The {Treasury} contract that will provide the ERC20 tokens and will be
    /// the recipient of the swapped WETH.
    address public immutable treasury;

    /**
     * Store our required information to action a swap.
     *
     * @param amount The amount of WETH to unwrap into ETH
     */
    struct ActionRequest {
        uint amount;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     *
     * @param _treasury Address of the Floor {Treasury} contract
     */
    constructor(address _treasury) {
        treasury = _treasury;
    }

    /**
     * Unwraps a fixed amount of WETH into ETH.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint The amount of ETH unwrapped from the WETH by the execution
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Transfer the WETH from the {Treasury} into the action
        IWETH(WETH).transferFrom(treasury, address(this), request.amount);
        require(IWETH(WETH).balanceOf(address(this)) == request.amount, 'Wrong amount');

        // Unwrap the WETH into ETH
        IWETH(WETH).withdraw(request.amount);

        // Transfer ETH to the {Treasury}
        (bool success, ) = treasury.call{value: request.amount}('');
        require(success, 'Eth send fail');

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury}.
        return request.amount;
    }

    /**
     * To receive ETH from the WETH's withdraw function (it won't work without it).
     */
    receive() external payable {}
}
