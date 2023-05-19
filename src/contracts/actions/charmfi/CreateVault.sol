// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AlphaVault} from '@charmfi/contracts/AlphaVault.sol';
import {PassiveStrategy} from '@charmfi/contracts/PassiveStrategy.sol';

import {Action} from '@floor/actions/Action.sol';

/**
 * Creates a Charm liquidity vault for 2 tokens.
 */
contract CharmCreateVault is Action {
    /**
     * This large struct will use 3 storage slots.
     */
    struct ActionRequest {
        // Vault parameters
        uint maxTotalSupply; // 256 / 256
        address uniswapPool; // 416 / 512
        uint24 protocolFee; // 440 / 512 (1e6 max in vault)
        // Strategy parameters
        int24 baseThreshold; // 464 / 512
        int24 limitThreshold; // 488 / 512
        int24 minTickMove; // 512 / 512
        uint40 period; // 552 / 768 (uint40 allows 35,000 years)
        int24 maxTwapDeviation; // 576 / 768
        uint32 twapDuration; // 608 / 768
        address keeper; // 768 / 768
    }

    function execute(bytes calldata _request) public payable override whenNotPaused returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Deploy our vault, referencing the uniswap pool
        AlphaVault alphaVault = new AlphaVault({
            _pool: request.uniswapPool,
            _protocolFee: uint(request.protocolFee),
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
        PassiveStrategy alphaStrategy = new PassiveStrategy({
            _vault: address(alphaVault),
            _baseThreshold: request.baseThreshold,
            _limitThreshold: request.limitThreshold,
            _period: uint(request.period),
            _minTickMove: request.minTickMove,
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
