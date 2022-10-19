// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * @dev
 */

interface IStrategyFactory {

    /**
     *
     */
    function getStrategies() external returns (address[] memory);

    /**
     *
     */
    function approveStrategy(address contractAddr) external;

    /**
     *
     */
    function revokeStrategy(address contractAddr) external;

}
