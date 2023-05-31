# CharmCreateVault
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/actions/charmfi/CreateVault.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Creates a Charm liquidity vault for 2 tokens.


## Functions
### execute


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest
This large struct will use 3 storage slots.


```solidity
struct ActionRequest {
    uint maxTotalSupply;
    address uniswapPool;
    uint24 protocolFee;
    int24 baseThreshold;
    int24 limitThreshold;
    int24 minTickMove;
    uint40 period;
    int24 maxTwapDeviation;
    uint32 twapDuration;
    address keeper;
}
```

