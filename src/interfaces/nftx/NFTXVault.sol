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

    function vaultId() external view returns (uint);
    function nftIdAt(uint holdingsIndex) external view returns (uint);
    function allHoldings() external view returns (uint[] memory);
    function totalHoldings() external view returns (uint);
    function mintFee() external view returns (uint);
    function randomRedeemFee() external view returns (uint);
    function targetRedeemFee() external view returns (uint);
    function randomSwapFee() external view returns (uint);
    function targetSwapFee() external view returns (uint);
    function vaultFees() external view returns (uint, uint, uint, uint, uint);

    function redeem(uint amount, uint[] calldata specificIds) external returns (uint[] calldata);

    function redeemTo(uint amount, uint[] calldata specificIds, address to) external returns (uint[] calldata);
}
