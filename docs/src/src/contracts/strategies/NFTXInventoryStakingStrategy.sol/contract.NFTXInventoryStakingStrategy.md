# NFTXInventoryStakingStrategy
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/strategies/NFTXInventoryStakingStrategy.sol)

**Inherits:**
[BaseStrategy](/src/contracts/strategies/BaseStrategy.sol/contract.BaseStrategy.md)

Supports an Inventory Staking position against a single NFTX vault. This strategy
will hold the corresponding xToken against deposits.
The contract will extend the {BaseStrategy} to ensure it conforms to the required
logic and functionality. Only functions that have varied internal logic have been
included in this interface with function documentation to explain.

*This contract does not support PUNK tokens. If a strategy needs to be established
then it should be done through another, bespoke contract.
https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract*


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
The reward yield will be a vault xToken as defined by the InventoryStaking contract.


```solidity
address public yieldToken;
```


### assetAddress
The ERC721 / ERC1155 token asset for the NFTX vault


```solidity
address public assetAddress;
```


### inventoryStaking
Address of the NFTX Inventory Staking contract


```solidity
INFTXInventoryStaking public inventoryStaking;
```


### stakingZap
The NFTX zap addresses


```solidity
INFTXStakingZap public stakingZap;
```


### unstakingZap

```solidity
INFTXUnstakingInventoryZap public unstakingZap;
```


### deposits
Track the amount of deposit token


```solidity
uint private deposits;
```


### _nftReceiver
Stores the temporary recipient of any ERC721 and ERC1155 tokens that are received
by the contract.


```solidity
address private _nftReceiver;
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

Deposit underlying token or yield token to corresponding strategy.
Requirements:
- Caller should make sure the token is already transfered into the strategy contract.
- Caller should make sure the deposit amount is greater than zero.
- Get the vault ID from the underlying address (vault address)
- InventoryStaking.deposit(uint256 vaultId, uint256 _amount)
- This deposit will be timelocked
- We receive xToken back to the strategy


```solidity
function depositErc20(uint amount) external nonReentrant whenNotPaused updatesPosition(yieldToken);
```

### depositErc721


```solidity
function depositErc721(uint[] calldata tokenIds) external updatesPosition(yieldToken);
```

### depositErc1155


```solidity
function depositErc1155(uint[] calldata tokenIds, uint[] calldata amounts) external updatesPosition(yieldToken);
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


### withdrawErc721


```solidity
function withdrawErc721(address _recipient, uint _numNfts, uint _partial) external nonReentrant onlyOwner;
```

### withdrawErc1155


```solidity
function withdrawErc1155(address _recipient, uint _numNfts, uint _partial) external nonReentrant onlyOwner;
```

### _unstakeInventory


```solidity
function _unstakeInventory(address _recipient, uint _numNfts, uint _partial) internal;
```

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

### onERC721Received

Allows the contract to receive ERC721 tokens.


```solidity
function onERC721Received(address, address, uint _id, bytes memory) public returns (bytes4);
```

### onERC1155Received

Allows the contract to receive ERC1155 tokens.


```solidity
function onERC1155Received(address, address, uint _id, uint _value, bytes calldata _data) public returns (bytes4);
```

### onERC1155BatchReceived

Allows the contract to receive batch ERC1155 tokens.


```solidity
function onERC1155BatchReceived(address, address, uint[] calldata _ids, uint[] calldata _values, bytes calldata _data)
    external
    returns (bytes4);
```

