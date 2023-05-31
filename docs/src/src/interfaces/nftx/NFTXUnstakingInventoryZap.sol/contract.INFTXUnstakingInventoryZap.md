# INFTXUnstakingInventoryZap
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/interfaces/nftx/NFTXUnstakingInventoryZap.sol)


## Functions
### unstakeInventory


```solidity
function unstakeInventory(uint vaultId, uint numNfts, uint remainingPortionToUnstake) external payable;
```

### maxNftsUsingXToken


```solidity
function maxNftsUsingXToken(uint vaultId, address staker, address slpToken) external returns (uint numNfts, bool shortByTinyAmount);
```

