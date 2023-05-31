# RevenueStakingStrategy
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/strategies/RevenueStakingStrategy.sol)

**Inherits:**
[BaseStrategy](/src/contracts/strategies/BaseStrategy.sol/contract.BaseStrategy.md)

Supports manual staking of "yield" from an authorised sender. This allows manual
yield management from external sources and products that cannot be strictly enforced
on-chain otherwise.
The contract will extend the {BaseStrategy} to ensure it conforms to the required
logic and functionality.

*This staking strategy will only accept ERC20 deposits and withdrawals.*


## State Variables
### _tokens
An array of tokens supported by the strategy


```solidity
address[] private _tokens;
```


## Functions
### initialize

Sets up our contract variables.


```solidity
function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`bytes32`|The name of the strategy|
|`_strategyId`|`uint256`|ID index of the strategy created|
|`_initData`|`bytes`|Encoded data to be decoded|


### depositErc20

Deposit a token that will be stored as a reward.


```solidity
function depositErc20(address token, uint amount) external nonReentrant whenNotPaused onlyValidToken(token) returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`||
|`amount`|`uint256`|Amount of token to deposit|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint Amount of token registered as rewards|


### withdrawErc20

Withdraws an amount of our position from the strategy.


```solidity
function withdrawErc20(address recipient, address token, uint amount)
    external
    nonReentrant
    onlyOwner
    onlyValidToken(token)
    returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`||
|`token`|`address`||
|`amount`|`uint256`|Amount of token to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint Amount of the token returned|


### available

Gets rewards that are available to harvest.

*This will always return two empty arrays as we will never have
tokens available to harvest.*


```solidity
function available() external view override returns (address[] memory tokens_, uint[] memory amounts_);
```

### harvest

There will never be any rewards to harvest in this strategy.


```solidity
function harvest(address _recipient) external override onlyOwner;
```

### validTokens

Returns an array of tokens that the strategy supports.


```solidity
function validTokens() external view override returns (address[] memory);
```

