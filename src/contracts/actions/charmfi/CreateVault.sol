// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TokenUtils} from '@floor/utils/TokenUtils.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IAlphaVault} from '@floor-interfaces/charm/AlphaVault.sol';


/**
 * Creates a Charm liquidity vault for 2 tokens.
 */
contract CharmCreateVault is IAction {

    struct ActionRequest {
        // Vault parameters
        uint protocolFee;
        uint maxTotalSupply;
        address uniswapPool;

        // Strategy parameters
        int24 baseThreshold;
        int24 limitThreshold;
        int24 maxTwapDeviation;
        uint32 twapDuration;
        address keeper;
    }

    function execute(bytes calldata _request) public returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest calldata request = abi.decode(_request, (ActionRequest));

        // Deploy our vault, referencing the uniswap pool
        IAlphaVault alphaVault = new AlphaVault({
            _pool: request.uniswapPool,
            _protocolFee: request.protocolFee,
            _maxTotalSupply: request.maxTotalSupply
        });

        /**
         * After deploying, strategy needs to be set via `setStrategy()`.
         *
         * @param _vault Underlying Alpha Vault
         * @param _baseThreshold Used to determine base order range
         * @param _limitThreshold Used to determine limit order range
         * @param _maxTwapDeviation Max deviation from TWAP during rebalance
         * @param _twapDuration TWAP duration in seconds for rebalance check
         * @param _keeper Account that can call `rebalance()`
         */
        IAlphaStrategy alphaStrategy = new AlphaStrategy({
            _vault: address(alphaVault),
            _baseThreshold: request.baseThreshold,
            _limitThreshold: request.limitThreshold,
            _maxTwapDeviation: request.maxTwapDeviation,
            _twapDuration: request.twapDuration,
            _keeper: request.keeper
        });

        // Set our strategy to the vault
        alphaVault.setStrategy(address(alphaStrategy));

        // We cast the pool address to an integer so that it can be returned
        return uint(uint160(address(alphaVault)));
    }
}
