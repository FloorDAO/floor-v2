# GemSweep
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/actions/gem/Sweep.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md), IERC721Receiver

**Author:**
Twade

Allows sweeping from Gem.xyz to facilitate the purchasing and immediate
staking of ERC721s.


## State Variables
### GEM_SWAP
Internal store of GemSwap contract


```solidity
address GEM_SWAP;
```


## Functions
### execute

Executes a Gem.xyz sweep to facilitate the purchase of ERC721s.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint spent);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|GemSwap transaction bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`spent`|`uint256`|The amount of ETH spent on the call|


### setGemSwap

Allows the owner to add a whitelisted address that can be passed as a
`target` in the `sweepAndStake` function. This can be either activated
or deactivated based on the `_value` passed.


```solidity
function setGemSwap(address _gemSwap) external onlyOwner;
```

### onERC721Received

Allows the contract to receive ERC721 tokens.


```solidity
function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4);
```

### receive

Allows our contract to receive dust ETH back from our Gem sweep.


```solidity
receive() external payable;
```

## Events
### Sweep
Emitted when a successful sweep takes place, showing the amount of
ETH spent on the sweep.


```solidity
event Sweep(uint ethAmount);
```

