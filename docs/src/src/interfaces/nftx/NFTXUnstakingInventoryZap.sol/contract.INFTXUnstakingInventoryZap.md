# INFTXUnstakingInventoryZap
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/nftx/NFTXUnstakingInventoryZap.sol)


## Functions
### unstakeInventory


```solidity
function unstakeInventory(uint vaultId, uint numNfts, uint remainingPortionToUnstake) external payable;
```

### maxNftsUsingXToken


```solidity
function maxNftsUsingXToken(uint vaultId, address staker, address slpToken) external returns (uint numNfts, bool shortByTinyAmount);
```

