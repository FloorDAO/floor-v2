# VaultFactory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/vaults/VaultFactory.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [IVaultFactory](/src/interfaces/vaults/VaultFactory.sol/contract.IVaultFactory.md)

Allows for vaults to be created, pairing them with a {Strategy} and an approved
collection. The vault creation script needs to be as highly optimised as possible
to ensure that the gas costs are kept down.
This factory will keep an index of created vaults and secondary information to ensure
that external applications can display and maintain a list of available vaults.
The contract can be paused to prevent the creation of new vaults.
Question: Can anyone create a vault?


## State Variables
### _vaults
Maintains an array of all vaults created


```solidity
address[] private _vaults;
```


### collectionRegistry
Contract mappings to our internal registries


```solidity
ICollectionRegistry public immutable collectionRegistry;
```


### strategyRegistry

```solidity
IStrategyRegistry public immutable strategyRegistry;
```


### vaultImplementation
Implementation addresses that will be cloned


```solidity
address public immutable vaultImplementation;
```


### vaultXTokenImplementation

```solidity
address public immutable vaultXTokenImplementation;
```


### vaultIds
Mappings to aide is discoverability


```solidity
mapping(uint => address) private vaultIds;
```


### collectionVaults

```solidity
mapping(address => address[]) private collectionVaults;
```


### floor
Internal contract references


```solidity
address public floor;
```


### staking

```solidity
address public staking;
```


## Functions
### constructor

Store our registries, mapped to their interfaces.


```solidity
constructor(
    address _authority,
    address _collectionRegistry,
    address _strategyRegistry,
    address _vaultImplementation,
    address _vaultXTokenImplementation,
    address _floor
) AuthorityControl(_authority);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_authority`|`address`|{AuthorityRegistry} contract address|
|`_collectionRegistry`|`address`|Address of our {CollectionRegistry}|
|`_strategyRegistry`|`address`|Address of our {StrategyRegistry}|
|`_vaultImplementation`|`address`|Address of our deployed {Vault} to clone|
|`_vaultXTokenImplementation`|`address`|Address of our deployed {VaultXToken} to clone|
|`_floor`|`address`|Address of our {FLOOR}|


### vaults

Provides a list of all vaults created.


```solidity
function vaults() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of all vaults created by the {VaultFactory}|


### vault

Provides a vault against the provided `vaultId` (index). If the index does not exist,
then address(0) will be returned.


```solidity
function vault(uint _vaultId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vaultId`|`uint256`|ID of the vault to cross check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the vault|


### vaultsForCollection

Provides a list of all vault addresses that have been set up for a
collection address.


```solidity
function vaultsForCollection(address _collection) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|Address of the collection to look up|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of vaults that reference the collection|


### createVault

Creates a vault with an approved strategy, collection and corresponding {VaultXToken}.


```solidity
function createVault(string memory _name, address _strategy, bytes memory _strategyInitData, address _collection)
    external
    onlyRole(STRATEGY_MANAGER)
    returns (uint vaultId_, address vaultAddr_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|Human-readable name of the vault|
|`_strategy`|`address`|The strategy implemented by the vault|
|`_strategyInitData`|`bytes`|Bytes data required by the {Strategy} for initialization|
|`_collection`|`address`|The address of the collection attached to the vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vaultId_`|`uint256`|ID of the newly created vault|
|`vaultAddr_`|`address`|Address of the newly created vault|


### pause

Allows individual vaults to be paused, meaning that assets can no longer be deposited,
although staked assets can always be withdrawn.

*Events are fired within the vault to allow listeners to update.*


```solidity
function pause(uint _vaultId, bool _paused) public onlyRole(STRATEGY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vaultId`|`uint256`|Vault ID to be updated|
|`_paused`|`bool`|If the vault should be paused or unpaused|


### migratePendingDeposits

Updates pending stakers into active stakers, entitling them to a share of the
vault rewards yield.

*This should be called when an epoch is ended.*


```solidity
function migratePendingDeposits(uint _vaultId) public onlyRole(STRATEGY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vaultId`|`uint256`|Vault ID to be updated|


### claimRewards


```solidity
function claimRewards(uint _vaultId) public onlyRole(TREASURY_MANAGER) returns (uint);
```

### distributeRewards

Distributes rewards into the {VaultXToken} via the {Vault}.


```solidity
function distributeRewards(uint _vaultId, uint _amount) public onlyRole(REWARDS_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vaultId`|`uint256`|Vault ID to be updated|
|`_amount`|`uint256`|Amount of reward tokens to be distributed|


### registerMint

..


```solidity
function registerMint(uint _vaultId, uint _amount) public onlyRole(TREASURY_MANAGER);
```

### setStakingContract

Allows the staking contract to be updated.


```solidity
function setStakingContract(address _staking) public onlyRole(STRATEGY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_staking`|`address`|Contract address of the staking contract to be set|


