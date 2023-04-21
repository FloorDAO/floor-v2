// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AlphaVault} from '@charmfi/contracts/AlphaVault.sol';

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';


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

    /**
     * ..
     */
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct and call our internal execute logic
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Load our vault so that we can directly query tokens
        AlphaVault vault = AlphaVault(request.vault);
        address token0 = address(vault.token0());
        address token1 = address(vault.token1());

        // Fetch tokens from address
        uint amount0Pulled = token0.pullTokensIfNeeded(msg.sender, request.amount0Desired);
        uint amount1Pulled = token1.pullTokensIfNeeded(msg.sender, request.amount1Desired);

        // Approve positionManager so it can pull tokens
        token0.approveToken(request.vault, amount0Pulled);
        token1.approveToken(request.vault, amount1Pulled);

        // Deposit tokens into the vault
        (uint shares, uint amount0, uint amount1) = vault.deposit({
            amount0Desired: request.amount0Desired,
            amount1Desired: request.amount1Desired,
            amount0Min: request.amount0Min,
            amount1Min: request.amount1Min,
            to: msg.sender
        });

        // Send leftovers back to the caller
        token0.withdrawTokens(msg.sender, request.amount0Desired - amount0);
        token1.withdrawTokens(msg.sender, request.amount1Desired - amount1);

        // Remove approvals
        token0.approveToken(request.vault, 0);
        token1.approveToken(request.vault, 0);

        return shares;
    }

}
