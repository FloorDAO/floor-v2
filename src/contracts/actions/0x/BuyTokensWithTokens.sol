// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * @notice Buy tokens on 0x using another token.
 */
contract BuyTokensWithTokens is IAction {
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

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
     * Buys tokens on 0x using another token.
     *
     * @param _request Bytes to be cast to the `ActionRequest` struct
     *
     * @return uint The amount of tokens bought
     */
    function execute(bytes calldata _request) public payable returns (uint received_) {
        // Unpack the request bytes data into individual variables, as mapping it directly
        // to the struct is buggy (due to bytes memory -> storage?).
        (address _sellToken, address _buyToken, bytes memory swapCallData) = abi.decode(_request, (address, address, bytes));

        if (_sellToken != ETH) {
            // Transfer our allowance of the `sellToken` from the {Treasury} so that
            // we can handle any amount request. We later transfer dust back if left.
            IERC20(_sellToken).transferFrom(treasury, address(this), IERC20(_sellToken).allowance(treasury, address(this)));
        } else {
            IWETH(WETH).deposit{value: msg.value}();
            _sellToken = WETH;
        }

        _buyToken = (_buyToken == ETH) ? WETH : _buyToken;

        // Set up our token references
        IERC20 buyToken = IERC20(_buyToken);
        IERC20 sellToken = IERC20(_sellToken);

        // Track our balance of the buyToken to determine how much we've bought.
        uint startAmountBuy = buyToken.balanceOf(address(this));

        // Transfer our allowance of the `sellToken` from the {Treasury} so that
        // we can handle any amount request. We later transfer dust back if left.
        if (_sellToken != WETH) {
            sellToken.transferFrom(treasury, address(this), sellToken.allowance(treasury, address(this)));
        }

        // Give `swapTarget` an allowance to spend this contract's `sellToken`.
        require(sellToken.approve(swapTarget, sellToken.balanceOf(address(this))), 'Unable to approve contract');

        // Call the encoded swap function call on the contract at `swapTarget`
        (bool success,) = swapTarget.call(swapCallData);
        require(success, 'SWAP_CALL_FAILED');

        // Use our current buyToken balance to determine how much we've bought.
        received_ = buyToken.balanceOf(address(this)) - startAmountBuy;

        // Transfer tokens back to the {Treasury}
        buyToken.transfer(treasury, received_);

        // If we still hold any `sellToken` then we can return this to the {Treasury} too
        uint sellTokenDust = sellToken.balanceOf(address(this));
        if (sellTokenDust != 0) {
            sellToken.transfer(treasury, sellTokenDust);
        }
    }
}
