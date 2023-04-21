// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAlphaVault {
    function deposit(
        uint256,
        uint256,
        uint256,
        uint256,
        address
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function withdraw(
        uint256,
        uint256,
        uint256,
        address
    ) external returns (uint256, uint256);

    function getTotalAmounts() external view returns (uint256, uint256);
}
