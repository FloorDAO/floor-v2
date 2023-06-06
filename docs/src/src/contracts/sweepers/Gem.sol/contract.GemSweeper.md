# GemSweeper
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/sweepers/Gem.sol)

**Inherits:**
[ISweeper](/src/interfaces/actions/Sweeper.sol/contract.ISweeper.md)

Interacts with the Gem.xyz protocol to fulfill a sweep order.


## Functions
### execute


```solidity
function execute(address[] calldata, uint[] calldata, bytes calldata data) external payable override returns (string memory);
```

### receive

Allows our contract to receive dust ETH back from our Gem sweep.


```solidity
receive() external payable;
```

