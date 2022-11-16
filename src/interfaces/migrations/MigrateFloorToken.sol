// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IMigrateFloorToken {

    /**
     * Burn FLOOR v1 tokens for FLOOR v2 tokens.
     */
    function upgradeFloorToken(uint amount) external;

    /**
     * Burn FLOOR v1 tokens for Treasury assets.
     */
    function redeemTreasuryAssets() external;

}
