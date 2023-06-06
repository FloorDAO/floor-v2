# NFTXLiquidityStakingStrategy
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/strategies/NFTXLiquidityStakingStrategy.sol)

**Inherits:**
[IBaseStrategy](/src/interfaces/strategies/BaseStrategy.sol/contract.IBaseStrategy.md), Initializable

Supports an Liquidity Staking position against a single NFTX vault. This strategy
holds the corresponding xSLP token against deposits.
The contract extends the {BaseStrategy} to ensure it conforms to the required
logic and functionality. Only functions that have varied internal logic have been
included in this interface with function documentation to explain.
https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract


## State Variables
### name
The human-readable name of the inventory strategy


```solidity
bytes32 public name;
```


### vaultId
The vault ID that the strategy is attached to


```solidity
uint public vaultId;
```


### vaultAddr
The address of the vault the strategy is attached to


```solidity
address public vaultAddr;
```


### pool

```solidity
address public pool;
```


### underlyingToken
The underlying token will be a liquidity SLP as defined by the {LiquidityStaking} contract.


```solidity
address public underlyingToken;
```


### yieldToken
The reward yield token will be the token defined in the {LiquidityStaking} contract.


```solidity
address public yieldToken;
```


### liquidityStaking
Address of the NFTX Liquidity Staking contract


```solidity
address public liquidityStaking;
```


### mintedRewards
This will return the internally tracked value of tokens that have been minted into
FLOOR by the {Treasury}.
This value is stored in terms of the `yieldToken`.


```solidity
uint public mintedRewards;
```


### lifetimeRewards
This will return the internally tracked value of tokens that have been claimed by
the strategy, regardless of if they have been minted into FLOOR.
This value is stored in terms of the `yieldToken`.


```solidity
uint private lifetimeRewards;
```


### deposits
This will return the internally tracked value of all deposits made into the strategy.
This value is stored in terms of the `yieldToken`.


```solidity
uint public deposits;
```


## Functions
### constructor

Sets our strategy name.


```solidity
constructor(bytes32 _name);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`bytes32`|Human-readable name of the strategy|


### initialize

Sets up our contract variables.


```solidity
function initialize(uint _vaultId, address _vaultAddr, bytes memory initData) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vaultId`|`uint256`|Numeric ID of vault the strategy is attached to|
|`_vaultAddr`|`address`|Address of vault the strategy is attached to|
|`initData`|`bytes`|Encoded data to be decoded|


### deposit

Deposit underlying token or yield token to corresponding strategy. This function expects
that the SLP token will be deposited and will not facilitate double sided staking or
handle the native chain token to balance the sides.
Requirements:
- Caller should make sure the token is already transfered into the strategy contract.
- Caller should make sure the deposit amount is greater than zero.
- Get the vault ID from the underlying address (vault address)
- LiquidityStaking.deposit(uint256 vaultId, uint256 _amount)
- This deposit will be timelocked
- If the pool currently has no liquidity, it will additionally
initialise the pool
- We receive xSLP back to the strategy


```solidity
function deposit(uint amount) external onlyVault returns (uint xTokensReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of underlying token to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`xTokensReceived`|`uint256`|Amount of yield token returned from NFTX|


### withdraw

Allows the user to burn xToken to receive back their original token.


```solidity
function withdraw(uint amount) external onlyVault returns (uint amount_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of yield token to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|Amount of the underlying token returned|


### claimRewards

Harvest possible rewards from strategy.


```solidity
function claimRewards() public returns (uint amount_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|Amount of rewards claimed|


### rewardsAvailable

The token amount of reward yield available to be claimed on the connected external
platform. Our `claimRewards` function will always extract the maximum yield, so this
could essentially return a boolean. However, I think it provides a nicer UX to
provide a proper amount and we can determine if it's financially beneficial to claim.
This value is stored in terms of the `yieldToken`.


```solidity
function rewardsAvailable() external view returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The available rewards to be claimed|


### totalRewardsGenerated

Total rewards generated by the strategy in all time. This is pure bragging rights.
This value is stored in terms of the `yieldToken`.


```solidity
function totalRewardsGenerated() external view returns (uint);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total rewards generated by strategy|


### unmintedRewards

The amount of reward tokens generated by the strategy that is allocated to, but has not
yet been, minted into FLOOR tokens. This will be calculated by a combination of an
internally incremented tally of claimed rewards, as well as the returned value of
`rewardsAvailable` to determine pending rewards.
This value is stored in terms of the `yieldToken`.


```solidity
function unmintedRewards() external view returns (uint amount_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|Amount of unminted rewards held in the contract|


### registerMint

This is a call that will only be available for the {Treasury} to indicate that it
has minted FLOOR and that the internally stored `mintedRewards` integer should be
updated accordingly.


```solidity
function registerMint(address recipient, uint amount) external onlyVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`||
|`amount`|`uint256`|Amount of token to be registered as minted|


### onlyVault

Allows us to restrict calls to only be made by the connected vaultId.


```solidity
modifier onlyVault();
```

