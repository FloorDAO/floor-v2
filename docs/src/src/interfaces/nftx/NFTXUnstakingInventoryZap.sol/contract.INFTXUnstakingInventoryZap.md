# INFTXUnstakingInventoryZap
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/nftx/NFTXUnstakingInventoryZap.sol)


## Functions
### unstakeInventory


```solidity
function unstakeInventory(uint vaultId, uint numNfts, uint remainingPortionToUnstake) external payable;
```

### maxNftsUsingXToken


```solidity
function maxNftsUsingXToken(uint vaultId, address staker, address slpToken) external returns (uint numNfts, bool shortByTinyAmount);
```

