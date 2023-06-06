# IVault
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/vaults/Vault.sol)


## Functions
### initialize

Set up our vault information.


```solidity
function initialize(string memory _name, uint _vaultId, address _collection, address _strategy, address _vaultFactory, address _vaultXToken)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|Human-readable name of the vault|
|`_vaultId`|`uint256`|The vault index ID assigned during creation|
|`_collection`|`address`|The address of the collection attached to the vault|
|`_strategy`|`address`|The strategy implemented by the vault|
|`_vaultFactory`|`address`|The address of the {VaultFactory} that created the vault|
|`_vaultXToken`|`address`|The address of the paired xToken|


### collection

Gets the contract address for the vault collection. Only assets from this contract
will be able to be deposited into the contract.


```solidity
function collection() external view returns (address);
```

### strategy

Gets the contract address for the strategy implemented by the vault.


```solidity
function strategy() external view returns (IBaseStrategy);
```

### vaultFactory

Gets the contract address for the vault factory that created it


```solidity
function vaultFactory() external view returns (address);
```

### vaultId

The numerical ID of the vault that acts as an index for the {VaultFactory}


```solidity
function vaultId() external view returns (uint);
```

### claimRewards

Allows the {Treasury} to claim rewards from the vault's strategy.


```solidity
function claimRewards() external returns (uint);
```

### lastEpochRewards

The amount of yield token generated in the last epoch by the vault.


```solidity
function lastEpochRewards() external returns (uint);
```

### deposit

Allows the user to deposit an amount of tokens that the approved {Collection} and
passes it to the {Strategy} to be staked.


```solidity
function deposit(uint amount) external returns (uint);
```

### withdraw

Allows the user to exit their position either entirely or partially.


```solidity
function withdraw(uint amount) external returns (uint);
```

### pause

Pauses deposits from being made into the vault. This should only be called by
a guardian or governor.


```solidity
function pause(bool pause) external;
```

### migratePendingDeposits

Recalculates the share ownership of each address with a position. This precursory
calculation allows us to save gas during epoch calculation.
This assumes that when a user enters or exits a position, that their address is
maintained correctly in the `stakers` array.


```solidity
function migratePendingDeposits() external;
```

### xToken

..


```solidity
function xToken() external returns (address);
```

### distributeRewards


```solidity
function distributeRewards(uint amount) external;
```

### registerMint


```solidity
function registerMint(address recipient, uint amount) external;
```

## Events
### VaultDeposit
*Emitted when a user deposits*


```solidity
event VaultDeposit(address depositor, address token, uint amount);
```

### VaultWithdrawal
*Emitted when a user withdraws*


```solidity
event VaultWithdrawal(address withdrawer, address token, uint amount);
```

