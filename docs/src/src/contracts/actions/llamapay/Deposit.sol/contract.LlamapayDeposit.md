# LlamapayDeposit
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/actions/llamapay/Deposit.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

Makes a deposit into a Llamapay pool. This subsidises salary and other outgoing
payments to the team and external third parties.


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

Executes our token deposit against our Llamapay router.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```

## Structs
### ActionRequest
Store our required information to action a deposit.


```solidity
struct ActionRequest {
    address token;
    uint amountToDeposit;
}
```

