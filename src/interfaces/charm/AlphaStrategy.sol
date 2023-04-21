// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAlphaStrategy {
    function rebalance() external;

    function shouldRebalance() external view returns (bool);
}
