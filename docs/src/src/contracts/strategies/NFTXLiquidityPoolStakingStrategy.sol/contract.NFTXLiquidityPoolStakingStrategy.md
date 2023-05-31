# NFTXLiquidityPoolStakingStrategy
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/strategies/NFTXLiquidityPoolStakingStrategy.sol)

**Inherits:**
[BaseStrategy](/src/contracts/strategies/BaseStrategy.sol/contract.BaseStrategy.md)

Supports an Liquidity Staking position against a single NFTX vault. This strategy
will hold the corresponding xToken against deposits.
The contract will extend the {BaseStrategy} to ensure it conforms to the required
logic and functionality. Only functions that have varied internal logic have been
included in this interface with function documentation to explain.

*This contract does not support PUNK tokens. If a strategy needs to be established
then it should be done through another, bespoke contract.*


## State Variables
### vaultId
The NFTX vault ID that the strategy is attached to


```solidity
uint public vaultId;
```


### underlyingToken
The underlying token will be the same as the address of the NFTX vault.


```solidity
address public underlyingToken;
```


### yieldToken
The yield token will be a vault xToken as defined by the LP contract.


```solidity
address public yieldToken;
```


### rewardToken
The reward token will be a vToken as defined by the LP contract.


```solidity
address public rewardToken;
```


### assetAddress
The ERC721 / ERC1155 token asset for the NFTX vault


```solidity
address public assetAddress;
```


### liquidityStaking
The NFTX zap addresses


```solidity
INFTXLiquidityStaking public liquidityStaking;
```


### stakingZap

```solidity
INFTXStakingZap public stakingZap;
```


### deposits
Track the amount of deposit token


```solidity
uint private deposits;
```


### WETH

```solidity
IWETH public WETH;
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

Deposit the underlying token into the LP staking pool.


```solidity
function depositErc20(uint amount) external nonReentrant whenNotPaused updatesPosition(yieldToken) returns (uint amount_);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|Amount of yield token returned from NFTX|


### depositErc721


```solidity
function depositErc721(uint[] calldata tokenIds, uint minWethIn, uint wethIn) external updatesPosition(yieldToken) refundsWeth;
```

### depositErc1155


```solidity
function depositErc1155(uint[] calldata tokenIds, uint[] calldata amounts, uint minWethIn, uint wethIn)
    external
    updatesPosition(yieldToken)
    refundsWeth;
```

### withdrawErc20

Withdraws an amount of our position from the NFTX strategy.


```solidity
function withdrawErc20(address recipient, uint amount) external nonReentrant onlyOwner returns (uint amount_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`||
|`amount`|`uint256`|Amount of yield token to withdraw|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount_`|`uint256`|Amount of the underlying token returned|


### available

Gets rewards that are available to harvest.


```solidity
function available() external view override returns (address[] memory tokens_, uint[] memory amounts_);
```

### harvest

Extracts all rewards from third party and moves it to a recipient. This should
only be called by a specific action via the {StrategyFactory}.


```solidity
function harvest(address _recipient) external override onlyOwner;
```

### validTokens

Returns an array of tokens that the strategy supports.


```solidity
function validTokens() external view override returns (address[] memory);
```

### updatesPosition

Increases our yield token position based on the logic transacted in the call.

*This should be called for any deposit calls made.*


```solidity
modifier updatesPosition(address token);
```

### refundsWeth


```solidity
modifier refundsWeth();
```

### onERC1155Received

Allows the contract to receive ERC1155 tokens.


```solidity
function onERC1155Received(address, address, uint, uint, bytes calldata) public view returns (bytes4);
```

### onERC1155BatchReceived

Allows the contract to receive batch ERC1155 tokens.


```solidity
function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external view returns (bytes4);
```

