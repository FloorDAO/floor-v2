# INFTXUnstakingInventoryZap
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/interfaces/nftx/NFTXUnstakingInventoryZap.sol)


## Functions
### unstakeInventory


```solidity
function unstakeInventory(uint vaultId, uint numNfts, uint remainingPortionToUnstake) external payable;
```

### maxNftsUsingXToken


```solidity
function maxNftsUsingXToken(uint vaultId, address staker, address slpToken) external returns (uint numNfts, bool shortByTinyAmount);
```

