# FloorNft
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/tokens/FloorNft.sol)

**Inherits:**
[ERC721Lockable](/src/contracts/tokens/extensions/ERC721Lockable.sol/contract.ERC721Lockable.md)


## State Variables
### supply
Maintain an index of our current supply


```solidity
uint private supply;
```


### uri
The URI of your IPFS/hosting server for the metadata folder


```solidity
string internal uri;
```


### cost
Price of one NFT


```solidity
uint public constant cost = 0.05 ether;
```


### maxSupply
The maximum supply of your collection


```solidity
uint public maxSupply;
```


### maxMintAmountPerTx
The maximum mint amount allowed per transaction


```solidity
uint public maxMintAmountPerTx;
```


### paused
The paused state for minting


```solidity
bool public paused = true;
```


### merkleRoot
The Merkle Root used for whitelist minting


```solidity
bytes32 internal merkleRoot;
```


### whitelistClaimed
Mapping of address to bool that determins wether the address already
claimed the whitelist mint.


```solidity
mapping(address => bool) public whitelistClaimed;
```


## Functions
### constructor

Constructor function that sets name and symbol of the collection, cost,
max supply and the maximum amount a user can mint per transaction.


```solidity
constructor(string memory _name, string memory _symbol, uint _maxSupply, uint _maxMintAmountPerTx) ERC721(_name, _symbol);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_name`|`string`|Name of the ERC721 token|
|`_symbol`|`string`|Symbol of the ERC721 token|
|`_maxSupply`|`uint256`|The maximum number of tokens mintable|
|`_maxMintAmountPerTx`|`uint256`|The maximum number of tokens mintable per transaction|


### totalSupply

Returns the current supply of the collection.


```solidity
function totalSupply() public view returns (uint);
```

### mint

Mint function to allow for public sale when not paused.


```solidity
function mint(uint _mintAmount) public payable mintCompliance(_mintAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mintAmount`|`uint256`|The number of tokens to mint|


### whitelistMint

The whitelist mint function to allow addresses on the merkle root to claim without
requiring a payment.


```solidity
function whitelistMint(bytes32[] calldata _merkleProof) public payable mintCompliance(1);
```

### tokenURI

Returns the Token URI with Metadata for specified token ID.


```solidity
function tokenURI(uint _tokenId) public view virtual override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_tokenId`|`uint256`|The token ID to get the metadata URI for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The metadata URI for the token ID|


### setMaxMintAmountPerTx

Set the maximum mint amount per transaction


```solidity
function setMaxMintAmountPerTx(uint _maxMintAmountPerTx) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_maxMintAmountPerTx`|`uint256`|The new maximum tx mint amount|


### setUri

Set the URI of your IPFS/hosting server for the metadata folder.

*Used in the format: "ipfs://your_uri/".*


```solidity
function setUri(string memory _uri) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_uri`|`string`|New metadata base URI|


### setPaused

Change paused state for main minting. When enabled will allow public minting
to take place.


```solidity
function setPaused(bool _state) public onlyOwner;
```

### setMerkleRoot

Set the Merkle Root for whitelist verification.


```solidity
function setMerkleRoot(bytes32 _newMerkleRoot) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newMerkleRoot`|`bytes32`|The new merkle root to assign to whitelist|


### setMaxSupply

Allows our max supply to be updated.


```solidity
function setMaxSupply(uint _maxSupply) external onlyOwner;
```

### withdraw

Allows ETH to be withdrawn from the contract after the minting.

*This should be sent to a {RevenueStakingStrategy} after being withdrawn
to promote yield generation.*


```solidity
function withdraw() public onlyOwner;
```

### _mintLoop

Helper function to process looped minting from different external functions.


```solidity
function _mintLoop(address _receiver, uint _mintAmount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_receiver`|`address`|Recipient of the NFT|
|`_mintAmount`|`uint256`|Number of tokens to mint to the receiver|


### _baseURI

The base of the metadata URI.


```solidity
function _baseURI() internal view virtual override returns (string memory);
```

### mintCompliance

Modifier that ensures the maximum supply and the maximum amount to mint per
transaction.


```solidity
modifier mintCompliance(uint _mintAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mintAmount`|`uint256`|The amount of tokens trying to be minted|


### receive

Allows the contract to receive payment for NFT sale.


```solidity
receive() external payable;
```

