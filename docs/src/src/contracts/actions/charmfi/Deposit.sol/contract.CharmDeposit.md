# CharmDeposit
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/actions/charmfi/Deposit.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Deposits tokens in proportion to the vault's current holdings.

*These tokens sit in the vault and are not used for liquidity on
Uniswap until the next rebalance. Also note it's not necessary to check
if user manipulated price to deposit cheaper, as the value of range
orders can only by manipulated higher.*


## Functions
### execute


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest

```solidity
struct ActionRequest {
    uint amount0Desired;
    uint amount1Desired;
    uint amount0Min;
    uint amount1Min;
    address vault;
}
```

