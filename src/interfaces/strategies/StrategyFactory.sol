// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Allows for vaults to be created, pairing them with a {Strategy} and an approved
 * collection. The vault creation script needs to be as highly optimised as possible
 * to ensure that the gas costs are kept down.
 *
 * This factory will keep an index of created vaults and secondary information to ensure
 * that external applications can display and maintain a list of available vaults.
 *
 * The contract can be paused to prevent the creation of new vaults.
 */

interface IStrategyFactory {
    /// @dev Sent when a vault is created successfully
    event VaultCreated(uint indexed vaultId, address vaultAddress, address assetAddress);

    /// @dev Sent when a vault is paused or unpaused
    event VaultCreationPaused(bool paused);

    /**
     * Provides a list of all strategies created.
     *
     * @return Array of all strategies created by the {StrategyFactory}
     */
    function strategies() external view returns (address[] memory);

    /**
     * Provides a strategy against the provided `strategyId` (index). If the index does not exist,
     * then address(0) will be returned.
     *
     * @param _strategyId ID of the strategy to retrieve
     *
     * @return Address of the strategy
     */
    function strategy(uint _strategyId) external view returns (address);

    /**
     * Creates a vault with an approved collection.
     *
     * @dev The vault is not created using Clones as there are complications when allocated
     * roles and permissions.
     *
     * @param _name Human-readable name of the vault
     * @param _strategy The strategy implemented by the vault
     * @param _strategyInitData Bytes data required by the {Strategy} for initialization
     * @param _collection The address of the collection attached to the vault
     *
     * @return strategyId_ ID of the newly created vault
     * @return strategyAddr_ Address of the newly created vault
     */
    function deployStrategy(bytes32 _name, address _strategy, bytes calldata _strategyInitData, address _collection)
        external
        returns (uint strategyId_, address strategyAddr_);

    /**
     * Allows individual vaults to be paused, meaning that assets can no longer be deposited,
     * although staked assets can always be withdrawn.
     *
     * @dev Events are fired within the vault to allow listeners to update.
     *
     * @param _strategyId Vault ID to be updated
     * @param _paused If the vault should be paused or unpaused
     */
    function pause(uint _strategyId, bool _paused) external;

    /**
     * TODO: ..
     */
    function snapshot(uint _strategyId) external /* TODO: onlyRole */ returns (address[] memory tokens, uint[] memory amounts);
}
