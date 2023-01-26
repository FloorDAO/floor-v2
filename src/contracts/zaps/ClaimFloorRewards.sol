// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/security/Pausable.sol';

import {IFLOOR} from '../../interfaces/tokens/Floor.sol';
import {IVaultXToken} from '../../interfaces/tokens/VaultXToken.sol';
import {IVault} from '../../interfaces/vaults/Vault.sol';
import {IVaultFactory} from '../../interfaces/vaults/VaultFactory.sol';

/**
 * Allows users to easily collect their FLOOR rewards from across all vaults and
 * their distributed VaultXToken rewards.
 */
contract ClaimFloorRewardsZap is Pausable {
    /// Internal xToken cache
    mapping(address => IVaultXToken) internal xTokenCache;

    /// Internal FLOOR contracts
    IFLOOR public immutable floor;
    IVaultFactory public immutable vaultFactory;

    /**
     * Map our contract addresses.
     *
     * @param _floor {FLOOR} contract address
     * @param _vaultFactory {VaultFactory} contract address
     */
    constructor(address _floor, address _vaultFactory) {
        floor = IFLOOR(_floor);
        vaultFactory = IVaultFactory(_vaultFactory);
    }

    /**
     * Allows a user to claim all {FLOOR} tokens allocated to them across all different
     * {VaultXToken} distributions.
     *
     * @return The amount of {FLOOR} claimed and transferred to the user
     */
    function claimFloor() public whenNotPaused returns (uint) {
        // Get start balance
        uint startBalance = floor.balanceOf(msg.sender);

        // Iterate the vaults and claim until we have reached our limit
        address[] memory vaults = vaultFactory.vaults();
        for (uint i; i < vaults.length;) {
            _cachedXToken(vaults[i]).withdrawReward(msg.sender);
            unchecked {
                ++i;
            }
        }

        return floor.balanceOf(msg.sender) - startBalance;
    }

    /**
     * The amount of {FLOOR} available for a specific user to claim from across the
     * different {VaultXToken} instances.
     *
     * @param _user User address to lookup
     *
     * @return available_ The amount of {FLOOR} tokens available to claim
     */
    function availableFloor(address _user) public whenNotPaused returns (uint available_) {
        address[] memory vaults = vaultFactory.vaults();

        // Iterate the vaults and sum the total dividend amounts
        for (uint i; i < vaults.length;) {
            available_ += _cachedXToken(vaults[i]).dividendOf(_user);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Caches the process of finding a xToken address from a vault address. This won't change
     * for a vault so we can maintain an internal mapping of vault address -> xToken.
     *
     * @param _vault The address of the vault
     *
     * @return IVaultXToken The {VaultXToken} attached to the vault
     */
    function _cachedXToken(address _vault) internal returns (IVaultXToken) {
        if (address(xTokenCache[_vault]) == address(0)) {
            xTokenCache[_vault] = IVaultXToken(IVault(_vault).xToken());
        }

        return xTokenCache[_vault];
    }
}
