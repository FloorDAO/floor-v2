# ClaimFloorRewardsZap
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/zaps/ClaimFloorRewards.sol)

**Inherits:**
Pausable

Allows users to easily collect their FLOOR rewards from across all vaults and
their distributed VaultXToken rewards.


## State Variables
### xTokenCache
Internal xToken cache


```solidity
mapping(address => IVaultXToken) internal xTokenCache;
```


### floor
Internal FLOOR contracts


```solidity
IFLOOR public immutable floor;
```


### vaultFactory

```solidity
IVaultFactory public immutable vaultFactory;
```


## Functions
### constructor

Map our contract addresses.


```solidity
constructor(address _floor, address _vaultFactory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_floor`|`address`|{FLOOR} contract address|
|`_vaultFactory`|`address`|{VaultFactory} contract address|


### claimFloor

Allows a user to claim all {FLOOR} tokens allocated to them across all different
{VaultXToken} distributions.


```solidity
function claimFloor() public whenNotPaused returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of {FLOOR} claimed and transferred to the user|


### availableFloor

The amount of {FLOOR} available for a specific user to claim from across the
different {VaultXToken} instances.


```solidity
function availableFloor(address _user) public whenNotPaused returns (uint available_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|User address to lookup|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`available_`|`uint256`|The amount of {FLOOR} tokens available to claim|


### _cachedXToken

Caches the process of finding a xToken address from a vault address. This won't change
for a vault so we can maintain an internal mapping of vault address -> xToken.


```solidity
function _cachedXToken(address _vault) internal returns (IVaultXToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`address`|The address of the vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IVaultXToken`|IVaultXToken The {VaultXToken} attached to the vault|


