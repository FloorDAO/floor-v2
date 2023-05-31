# NftStakingNFTXV2
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/staking/strategies/NftStakingNFTXV2.sol)

**Inherits:**
[INftStakingStrategy](/src/interfaces/staking/strategies/NftStakingStrategy.sol/contract.INftStakingStrategy.md), Ownable

This contract allows approved collection NFTs to be depoited into it to generate
additional vote reward boosting through the calculation of a multiplier.


## State Variables
### underlyingTokenMapping
Stores the equivalent ERC20 of the ERC721


```solidity
mapping(address => address) public underlyingTokenMapping;
```


### underlyingXTokenMapping

```solidity
mapping(address => address) public underlyingXTokenMapping;
```


### cachedNftxVaultId
Store a mapping of NFTX vault address to vault ID for gas savings


```solidity
mapping(address => uint) internal cachedNftxVaultId;
```


### stakingZap
Store our NFTX staking zaps


```solidity
INFTXStakingZap public stakingZap;
```


### unstakingZap

```solidity
INFTXUnstakingInventoryZap public unstakingZap;
```


### _nftReceiver
Temp. user store for ERC721 receipt


```solidity
address private _nftReceiver;
```


### inventoryStaking
Allows NFTX references for when receiving rewards


```solidity
address internal inventoryStaking;
```


### treasury

```solidity
address internal treasury;
```


### nftStaking

```solidity
address internal immutable nftStaking;
```


### tokensStaked
Keep track of the number of token deposits to calculate rewards available


```solidity
uint internal tokensStaked;
```


## Functions
### constructor

Sets up our immutable contract addresses.


```solidity
constructor(address _nftStaking);
```

### approvalAddress

Shows the address that should be approved by a staking user.

*NFTX zap does not allow tokens to be sent from anyone other than caller.*


```solidity
function approvalAddress() external view returns (address);
```

### stake

Stakes an approved collection NFT into the contract and provides a boost based on
the price of the underlying ERC20.

*This can only be called when the contract is not paused.*


```solidity
function stake(address _user, address _collection, uint[] calldata _tokenId, uint[] calldata _amount, bool _is1155)
    external
    onlyNftStaking;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|Address of the user staking their tokens|
|`_collection`|`address`|Approved collection contract|
|`_tokenId`|`uint256[]`||
|`_amount`|`uint256[]`||
|`_is1155`|`bool`|If the collection is an ERC1155 standard|


### unstake

Unstakes an approved NFT from the contract and reduced the user's boost based on
the relevant metadata on the NFT.


```solidity
function unstake(address recipient, address _collection, uint numNfts, uint baseNfts, uint remainingPortionToUnstake, bool)
    external
    onlyNftStaking;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the unstaked NFT|
|`_collection`|`address`|The collection to unstake|
|`numNfts`|`uint256`|The number of NFTs to unstake for the recipient|
|`baseNfts`|`uint256`|The number of NFTs that this unstaking represents|
|`remainingPortionToUnstake`|`uint256`|The dust of NFT to unstake|
|`<none>`|`bool`||


### rewardsAvailable

Determines the amount of rewards available to be collected.


```solidity
function rewardsAvailable(address _collection) external returns (uint);
```

### claimRewards

Allows rewards to be claimed from the staked NFT inventory positions.


```solidity
function claimRewards(address _collection) external returns (uint rewardsAvailable_);
```

### underlyingToken

Gets the underlying token for a collection.


```solidity
function underlyingToken(address _collection) external view returns (address);
```

### setStakingZaps

Sets the NFTX staking zaps that we will be interacting with.


```solidity
function setStakingZaps(address _stakingZap, address _unstakingZap) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakingZap`|`address`|The {NFTXStakingZap} contract address|
|`_unstakingZap`|`address`|The {NFTXUnstakingInventoryZap} contract address|


### setContracts

Allows us to set internal contracts that are used when claiming rewards.


```solidity
function setContracts(address _inventoryStaking, address _treasury) external onlyOwner;
```

### setUnderlyingToken

Maps a collection address to an underlying NFTX token address. This will allow us to assign
a corresponding NFTX vault against our collection.


```solidity
function setUnderlyingToken(address _collection, address _token, address _xToken) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|Our approved collection address|
|`_token`|`address`|The underlying token (the NFTX vault contract address)|
|`_xToken`|`address`||


### _getVaultId

Calculates the NFTX vault ID of a collection address and then stores it to a local cache
as this value will not change.


```solidity
function _getVaultId(address _collection) internal returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collection`|`address`|The address of the collection being checked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Numeric NFTX vault ID|


### onERC721Received

Allows the contract to receive ERC721 tokens.


```solidity
function onERC721Received(address, address, uint tokenId, bytes memory) public virtual returns (bytes4);
```

### onERC1155Received

Allows the contract to receive ERC1155 tokens.


```solidity
function onERC1155Received(address, address, uint tokenId, uint amount, bytes calldata) public virtual returns (bytes4);
```

### onERC1155BatchReceived

Allows the contract to receive batch ERC1155 tokens.


```solidity
function onERC1155BatchReceived(address, address, uint[] calldata tokenIds, uint[] calldata amounts, bytes calldata)
    public
    virtual
    returns (bytes4);
```

### onlyNftStaking

Ensures that only the {NftStaking} contract can call the function.


```solidity
modifier onlyNftStaking();
```

