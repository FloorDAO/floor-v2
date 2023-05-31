# Option
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/options/Option.sol)

**Inherits:**
ERC721URIStorage


## State Variables
### _tokenIdTracker

```solidity
Counters.Counter private _tokenIdTracker;
```


### dna
The DNA of our Option defines the struct of our Option, but without the
space allocation requirement. We do this through using byte manipulation.
In this we reference the following:
[allocation][reward amount][rarity][pool id]
8             8           4       8
This DNA will not be unique as the ID value of this DNA will not be unique
as we don't factor in the ID of the token. This ID will be a uint256 and the
purpose of using bytes is to keep it within a fixed, predictable amount.
/// @dev 798 gas cost :)
function concatBytes(
bytes2 _c,
bytes2 _d
) public pure returns (bytes4) {
return (_c << 4) | _d;
}


```solidity
mapping(uint => bytes32) private dna;
```


## Functions
### constructor


```solidity
constructor() ERC721('FloorOption', 'FOPT');
```

### allocation

Gets the allocation granted to the Option.


```solidity
function allocation(uint tokenId) public view returns (uint);
```

### rewardAmount

Gets the reward amount granted to the Option.


```solidity
function rewardAmount(uint tokenId) public view returns (uint);
```

### rarity

Gets the rarity of the Option, calculated at point of mint.


```solidity
function rarity(uint tokenId) public view returns (uint);
```

### poolId

Gets the pool ID that the Option is attributed to.


```solidity
function poolId(uint tokenId) public view returns (uint);
```

### sliceUint

Takes a bytes input and converts it to an integer


```solidity
function sliceUint(bytes32 bs, uint start) internal pure returns (uint x);
```

### mint

Mints our token with a set DNA.


```solidity
function mint(address _to, bytes32 _dna) public virtual;
```

### baseURI

Save bytecode by removing implementation of unused method.


```solidity
function baseURI() public pure returns (string memory);
```

### _beforeTokenTransfer


```solidity
function _beforeTokenTransfer(address from, address to, uint firstTokenId, uint batchSize) internal virtual override;
```

