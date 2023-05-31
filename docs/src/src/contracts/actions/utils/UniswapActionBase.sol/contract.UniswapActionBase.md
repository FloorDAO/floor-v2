# UniswapActionBase
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/utils/UniswapActionBase.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md), IERC721Receiver

**Author:**
Twade

An abstract contract that provides helpers functions and logic for our UniSwap actions.


## State Variables
### positionManager
Stores our Uniswap position manager


```solidity
IUniswapV3NonfungiblePositionManager public positionManager;
```


## Functions
### _setPositionManager

Assigns our Uniswap V3 position manager contract that will be called at
various points to interact with the platform.


```solidity
function _setPositionManager(address _positionManager) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_positionManager`|`address`|The address of the UV3 position manager contract|


### onERC721Received

Implementing `onERC721Received` so this contract can receive custody of erc721 tokens.

*Note that the operator is recorded as the owner of the deposited NFT.*


```solidity
function onERC721Received(address, address, uint, bytes calldata) external view override returns (bytes4);
```

### requiresUniswapToken

Flash loans a Uniswap ERC token, specified by the ID passed, to this contract so
that it can undertake additional logic. This is required as Uniswap checks that the
calling contract owns the token as a permissions system.


```solidity
modifier requiresUniswapToken(uint tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID of the Uniswap token|


