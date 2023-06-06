# UserIsNotTokenOwner
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/staking/BoostStaking.sol)

require(tokenStaked[_tokenId] != msg.sender, 'Not owner');


```solidity
error UserIsNotTokenOwner(uint tokenId);
```

