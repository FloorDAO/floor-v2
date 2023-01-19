// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IMigrateFloorToken {
    function mintTokens(uint256 _amount) external;

    /**
     * Burns FLOOR v1 tokens for FLOOR v2 tokens. We have a list of the defined
     * V1 tokens in our test suites that should be accept. These include a, g and
     * s floor variants.
     *
     * This should provide a 1:1 V1 burn > V2 mint of tokens.
     *
     * The balance of all tokens will be attempted to be migrated, so 4 full approvals
     * should be made prior to calling this contract function.
     */
    function upgradeFloorToken() external;
}
