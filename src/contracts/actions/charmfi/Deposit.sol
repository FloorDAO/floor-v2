// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IAlphaVault} from '@floor-interfaces/charm/AlphaVault.sol';


/**
 * Deposits tokens in proportion to the vault's current holdings.
 *
 * @dev These tokens sit in the vault and are not used for liquidity on
 * Uniswap until the next rebalance. Also note it's not necessary to check
 * if user manipulated price to deposit cheaper, as the value of range
 * orders can only by manipulated higher.
 */
contract CharmDeposit is IAction {
    using TokenUtils for address;

    /// @param amount0Desired Max amount of token0 to deposit
    /// @param amount1Desired Max amount of token1 to deposit
    /// @param amount0Min Revert if resulting `amount0` is less than this
    /// @param amount1Min Revert if resulting `amount1` is less than this
    /// @param vault Vault to deposit into
    struct ActionRequest {
        uint amount0Desired;
        uint amount1Desired;
        uint amount0Min;
        uint amount1Min;
        address vault;
    }

    /// ..
    IAlphaVault public immutable charmVault;

    /**
     * ..
     */
    function execute(bytes calldata _request) public returns (uint) {
        // Unpack the request bytes data into our struct and call our internal execute logic
        ActionRequest calldata request = _execute(abi.decode(_request, (ActionRequest)));

        // Fetch tokens from address
        uint amount0Pulled = request.token0.pullTokensIfNeeded(msg.sender, request.amount0Desired);
        uint amount1Pulled = request.token1.pullTokensIfNeeded(msg.sender, request.amount1Desired);

        // Approve positionManager so it can pull tokens
        request.token0.approveToken(request.vault, amount0Pulled);
        request.token1.approveToken(request.vault, amount1Pulled);

        // Deposit tokens into the vault
        (uint shares, uint amount0, uint amount1) = IAlphaVault(request.vault).deposit({
            amount0Desired: request.amount0Desired,
            amount1Desired: request.amount1Desired,
            amount0Min: request.amount0Min,
            amount1Min: request.amount1Min,
            to: msg.sender
        });

        // Send leftovers back to the caller
        request.token0.withdrawTokens(msg.sender, request.amount0Desired - amount0);
        request.token1.withdrawTokens(msg.sender, request.amount1Desired - amount1);

        // Remove approvals
        request.token0.approveToken(request.vault, 0);
        request.token1.approveToken(request.vault, 0);

        return shares;
    }

}
