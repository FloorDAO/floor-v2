// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXVault {
    function manager() external view returns (address);
    function assetAddress() external view returns (address);

    function is1155() external view returns (bool);
    function allowAllItems() external view returns (bool);
    function enableMint() external view returns (bool);
    function enableRandomRedeem() external view returns (bool);
    function enableTargetRedeem() external view returns (bool);
    function enableRandomSwap() external view returns (bool);
    function enableTargetSwap() external view returns (bool);

    function vaultId() external view returns (uint256);
    function nftIdAt(uint256 holdingsIndex) external view returns (uint256);
    function allHoldings() external view returns (uint256[] memory);
    function totalHoldings() external view returns (uint256);
    function mintFee() external view returns (uint256);
    function randomRedeemFee() external view returns (uint256);
    function targetRedeemFee() external view returns (uint256);
    function randomSwapFee() external view returns (uint256);
    function targetSwapFee() external view returns (uint256);
    function vaultFees() external view returns (uint256, uint256, uint256, uint256, uint256);

    function redeem(uint256 amount, uint256[] calldata specificIds) external returns (uint256[] calldata);

    function redeemTo(uint256 amount, uint256[] calldata specificIds, address to)
        external
        returns (uint256[] calldata);
}
