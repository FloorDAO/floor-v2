// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAction} from '../../../interfaces/actions/Action.sol';

/**
 * @notice Buy tokens on 0x using another token.
 */
contract BuyTokensWithTokens is IAction {

    /// Internal store of desired 0x contract
    address public immutable swapTarget;

    /// Internal address of our {Treasury}
    address public immutable treasury;

    /**
     * Store our required information to action a swap.
     */
    struct ActionRequest {
        address sellToken;
        address buyToken;
        bytes swapCallData;
    }

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     *
     * @param _swapTarget Address of the 0x swap contract
     * @param _treasury Address of the Floor {Treasury} contract
     */
    constructor(address _swapTarget, address _treasury) {
        swapTarget = _swapTarget;
        treasury = _treasury;
    }

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint received_) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        console.log(address(this));
        console.log(treasury);
        console.log(request.sellToken);
        console.log(request.buyToken);
        console.logBytes(request.swapCallData);

        // Set up our token references
        IERC20 buyToken = IERC20(request.buyToken);
        IERC20 sellToken = IERC20(request.sellToken);

        console.log('A');

        // Track our balance of the buyToken to determine how much we've bought.
        uint256 startAmountBuy = buyToken.balanceOf(address(this));
        uint256 startAmountSell = sellToken.balanceOf(address(this));

        console.log('B');

        // Transfer our allowance of the `sellToken` from the {Treasury} so that
        // we can handle any amount request. We later transfer dust back if left.
        sellToken.transferFrom(treasury, address(this), sellToken.allowance(treasury, address(this)));

        console.log('C');

        // Give `swapTarget` an allowance to spend this contract's `sellToken`.
        require(sellToken.approve(swapTarget, sellToken.balanceOf(address(this))), 'Unable to approve contract');

        console.log('D');

        // Call the encoded swap function call on the contract at `swapTarget`
        (bool success,) = swapTarget.call(request.swapCallData);
        require(success, 'SWAP_CALL_FAILED');

        console.log('E');

        // Use our current buyToken balance to determine how much we've bought.
        received_ = buyToken.balanceOf(address(this)) - startAmountBuy;

        console.log('F');

        // Transfer tokens back to the {Treasury}
        buyToken.transfer(treasury, received_);

        console.log('G');

        // If we still hold any `sellToken` then we can return this to the {Treasury} too
        uint sellTokenDust = startAmountSell - sellToken.balanceOf(address(this));
        if (sellTokenDust != 0) {
            console.log('H');
            sellToken.transfer(treasury, sellTokenDust);
        }
    }

}
