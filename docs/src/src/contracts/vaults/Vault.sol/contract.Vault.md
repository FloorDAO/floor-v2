# Vault
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/vaults/Vault.sol)

**Inherits:**
[IVault](/src/interfaces/vaults/Vault.sol/contract.IVault.md), OwnableUpgradeable, ReentrancyGuard

Vaults are responsible for handling end-user token transactions with regards
to staking and withdrawal. Each vault will have a registered {Strategy} and
{Collection} that it will subsequently interact with and maintain.
If a user deposits, they won't receive an xToken allocation until the current
epoch has ended (called by `migratePendingDeposits` in the {Vault}). This ensures
that epochs cannot be sniped by front-running the epoch with a large deposit,
claiming a substantial share of the rewards that others generated, and the exiting.


## State Variables
### name
The human-readable name of the vault.


```solidity
string public name;
```


### vaultId
The numerical ID of the vault that acts as an index for the {VaultFactory}


```solidity
uint public vaultId;
```


### collection
Gets the contract address for the vault collection. Only assets from this contract
will be able to be deposited into the contract.


```solidity
address public collection;
```


### strategy
Gets the contract address for the strategy implemented by the vault.


```solidity
IBaseStrategy public strategy;
```


### vaultFactory
Gets the contract address for the vault factory that created it.


```solidity
address public vaultFactory;
```


### paused
Store if our Vault is paused, restricting access.


```solidity
bool public paused;
```


### pendingPositions
Maintain a mapped list of user positions based on withdrawal and
deposits. This will be used to calculate pool share and determine
the rewards generated for the user, as well as sense check withdrawal
request amounts.


```solidity
mapping(address => uint) public pendingPositions;
```


### pendingStakers
Maintain a list of addresses with positions. This allows us to iterate
our mappings to determine share ownership.


```solidity
address[] public pendingStakers;
```


### vaultXToken
Stores an address to our vault's {VaultXToken} contract.


```solidity
address internal vaultXToken;
```


### lastEpochRewards
The amount of rewards claimed in the last claim call.


```solidity
uint public lastEpochRewards;
```


## Functions
### initialize

Set up our vault information.


```solidity
function initialize(string memory _name, uint _vaultId, address _collection, address _strategy, address _vaultFactory, address _vaultXToken)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|Human-readable name of the vault|
|`_vaultId`|`uint256`||
|`_collection`|`address`|The address of the collection attached to the vault|
|`_strategy`|`address`|The strategy implemented by the vault|
|`_vaultFactory`|`address`|The address of the {VaultFactory} that created the vault|
|`_vaultXToken`|`address`|The address of the paired xToken|


### deposit

Allows the user to deposit an amount of tokens that the approved {Collection} and
passes it to the {Strategy} to be staked.


```solidity
function deposit(uint amount) external nonReentrant returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of tokens to be deposited by the user|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of xToken received from the deposit|


### withdraw

Allows the user to exit their position either entirely or partially.


```solidity
function withdraw(uint amount) external nonReentrant returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of tokens returned to the user|


### pause

Pauses deposits from being made into the vault. This should only be called by
a guardian or governor.


```solidity
function pause(bool _pause) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_pause`|`bool`|Boolean value for if the vault should be paused|


### claimRewards

Allows the {Treasury} to claim rewards from the vault's strategy.


```solidity
function claimRewards() external onlyOwner returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of rewards waiting to be minted into {FLOOR}|


### registerMint

..


```solidity
function registerMint(address recipient, uint _amount) external onlyOwner;
```

### migratePendingDeposits

Migrates any pending depositers and mints their {VaultXToken}s.


```solidity
function migratePendingDeposits() external onlyOwner;
```

### distributeRewards

Distributes rewards into the connected {VaultXToken}. This expects that the reward
token has already been transferred into the {VaultXToken} contract.


```solidity
function distributeRewards(uint amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of reward tokens to be distributed into the xToken|


### xToken

Returns a publically accessible address for the connected {VaultXToken}.


```solidity
function xToken() public view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|{VaultXToken} address|


### position

Returns a user's held position in a vault by referencing their {VaultXToken}
balance. Pending deposits will not be included in this return.


```solidity
function position(address user) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of user to find position of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The user's non-pending balance|


### share

Returns the percentage share that the user holds of the vault. This will, in
turn, represent the share of rewards that the user is entitled to when the next
epoch ends.


```solidity
function share(address user) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of user to find share of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Percentage share holding of vault|


