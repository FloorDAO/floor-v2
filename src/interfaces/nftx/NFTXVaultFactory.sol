// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTXVaultFactory {
    // Read functions.
    function numVaults() external view returns (uint);

    function zapContract() external view returns (address);

    function zapContracts(address addr) external view returns (bool);

    function feeDistributor() external view returns (address);

    function eligibilityManager() external view returns (address);

    function vault(uint vaultId) external view returns (address);

    function allVaults() external view returns (address[] memory);

    function vaultsForAsset(address asset) external view returns (address[] memory);

    function isLocked(uint id) external view returns (bool);

    function excludedFromFees(address addr) external view returns (bool);

    function factoryMintFee() external view returns (uint64);

    function factoryRandomRedeemFee() external view returns (uint64);

    function factoryTargetRedeemFee() external view returns (uint64);

    function factoryRandomSwapFee() external view returns (uint64);

    function factoryTargetSwapFee() external view returns (uint64);

    function vaultFees(uint vaultId) external view returns (uint, uint, uint, uint, uint);

    event NewFeeDistributor(address oldDistributor, address newDistributor);
    event NewZapContract(address oldZap, address newZap);
    event UpdatedZapContract(address zap, bool excluded);
    event FeeExclusion(address feeExcluded, bool excluded);
    event NewEligibilityManager(address oldEligManager, address newEligManager);
    event NewVault(uint indexed vaultId, address vaultAddress, address assetAddress);
    event UpdateVaultFees(uint vaultId, uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee);
    event DisableVaultFees(uint vaultId);
    event UpdateFactoryFees(uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee);

    // Write functions.
    function __NFTXVaultFactory_init(address _vaultImpl, address _feeDistributor) external;

    function createVault(string calldata name, string calldata symbol, address _assetAddress, bool is1155, bool allowAllItems)
        external
        returns (uint);

    function setFeeDistributor(address _feeDistributor) external;

    function setEligibilityManager(address _eligibilityManager) external;

    function setZapContract(address _zapContract, bool _excluded) external;

    function setFeeExclusion(address _excludedAddr, bool excluded) external;

    function setFactoryFees(uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee) external;

    function setVaultFees(uint vaultId, uint mintFee, uint randomRedeemFee, uint targetRedeemFee, uint randomSwapFee, uint targetSwapFee)
        external;

    function disableVaultFees(uint vaultId) external;
}
