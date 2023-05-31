# NewCollectionWarOptions
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/voting/NewCollectionWarOptions.sol)

**Inherits:**
[EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), IERC1155Receiver, IERC721Receiver, [INewCollectionWarOptions](/src/interfaces/voting/NewCollectionWarOptions.sol/contract.INewCollectionWarOptions.md), PullPayment

Expanding upon the logic in the {NewCollectionWar} contract, this allows for options to
be created by staking a full-price or discounted NFT that can be exercised by the DAO or
Floor NFT holders.


## State Variables
### treasury
Internal contract mappings


```solidity
ITreasury public immutable treasury;
```


### newCollectionWars

```solidity
INewCollectionWars public immutable newCollectionWars;
```


### floorNft
Internal floor NFT mapping


```solidity
address public immutable floorNft;
```


### nftVotingPowerCalculator
Internal NFT Option Calculator


```solidity
INftVotingPowerCalculator public nftVotingPowerCalculator;
```


### userVotes
Stores the number of votes a user has placed against a war collection


```solidity
mapping(bytes32 => uint) public userVotes;
```


### stakedTokens
Stores an array of tokens staked against a war collection

*(War -> Collection -> Price) => Option[]*


```solidity
mapping(bytes32 => Option[]) internal stakedTokens;
```


## Functions
### constructor

Sets our internal contract addresses.


```solidity
constructor(address _floorNft, address _treasury, address _newCollectionWars);
```

### createOption

Allows the user to deposit their ERC721 or ERC1155 into the contract and
gain additional voting power based on the floor price attached to the
collection in the FloorWar.


```solidity
function createOption(uint war, address collection, uint[] calldata tokenIds, uint40[] calldata amounts, uint56[] calldata exercisePercents)
    external;
```

### reclaimOptions

If the FloorWar has not yet ended, or the NFT timelock has expired, then the
user reclaim the staked NFT and return it to their wallet.
start    current
0        0         < locked
0        1         < locked if won for DAO
0        2         < locked if won for Floor NFT holders
0        3         < free


```solidity
function reclaimOptions(uint war, address collection, uint56[] calldata exercisePercents, uint[][] calldata indexes) external;
```

### exerciseOptions

Allows an approved user to exercise the staked NFT at the price that it was
listed at by the staking user.


```solidity
function exerciseOptions(uint war, uint amount) external payable;
```

### holderExerciseOptions

We now have the option for one of two approaches. We need to allocate
funds to each user, and also transfer the token. Ideally we would batch
up these requests, but it is unlikely that the additional gas costs in
storing these batches calls would out-weigh the cost of transferring
individually.
Allows a Floor NFT token holder to exercise a staked NFT at the price that it
was listed at by the staking user.


```solidity
function holderExerciseOptions(uint war, uint tokenId, uint56 exercisePercent, uint stakeIndex) external payable;
```

### _isCollectionInWar

Check if a collection is in a FloorWar.


```solidity
function _isCollectionInWar(bytes32 warCollection) internal view returns (bool);
```

### nftVotingPower

Determines the voting power given by a staked NFT based on the requested
exercise price and the spot price.


```solidity
function nftVotingPower(uint war, address collection, uint spotPrice, uint exercisePercent) external view returns (uint);
```

### setNftVotingPowerCalculator

Allows the calculator used to determine the `votingPower` to be updated.


```solidity
function setNftVotingPowerCalculator(address _calculator) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_calculator`|`address`|The address of the new calculator|


### onERC721Received

Allows ERC721's to be received via safeTransfer calls.


```solidity
function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4);
```

### onERC1155Received

Allows ERC1155's to be received via safeTransfer calls.


```solidity
function onERC1155Received(address, address, uint, uint, bytes calldata) external pure returns (bytes4);
```

### onERC1155BatchReceived

Allows batched ERC1155's to be received via safeTransfer calls.


```solidity
function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4);
```

### supportsInterface

Inform other contracts that we support the 721 and 1155 interfaces.


```solidity
function supportsInterface(bytes4) external pure returns (bool);
```

