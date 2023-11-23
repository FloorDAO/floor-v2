// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';

/**
 * Deploys our collection registry and approves our default collections.
 */
contract GetStrategyAvailableTokens is DeploymentScript {
    function run() external deployer {
        // Load and cast our Collection Registry
        IBaseStrategy strategy = IBaseStrategy(0xef965FE547934e2498b6EB3f3E021810B203069b);

        // Set up our approved collections
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        for (uint i; i < tokens.length; ++i) {
            console.log(tokens[i]);
            console.log(amounts[i]);
            console.log('---');
        }
    }
}
