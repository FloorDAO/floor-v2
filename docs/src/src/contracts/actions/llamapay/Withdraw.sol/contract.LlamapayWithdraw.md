# LlamapayWithdraw
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/actions/llamapay/Withdraw.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Withdraws tokens from a Llamapay pool.


## State Variables
### llamapayRouter
Our internally deployed Llamapay router


```solidity
LlamapayRouter public immutable llamapayRouter;
```


## Functions
### constructor

We assign any variable contract addresses in our constructor, allowing us
to have multiple deployed actions if any parameters change.


```solidity
constructor(LlamapayRouter _llamapayRouter);
```

### execute

Executes our token withdrawal against our Llamapay router.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest
Store our required information to action a withdrawal.


```solidity
struct ActionRequest {
    address token;
    uint amount;
}
```

