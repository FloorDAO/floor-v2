# CowSwapSweeper
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/sweepers/CowSwap.sol)

**Inherits:**
[ICoWSwapOnchainOrders](/src/interfaces/cowswap/CoWSwapOnchainOrders.sol/contract.ICoWSwapOnchainOrders.md), [ISweeper](/src/interfaces/actions/Sweeper.sol/contract.ISweeper.md)

Interacts with the CowSwap protocol to fulfill a sweep order.
Based on codebase:
https://github.com/nlordell/dappcon-2022-smart-orders


## State Variables
### APP_DATA

```solidity
bytes32 public constant APP_DATA = keccak256('floordao');
```


### settlement

```solidity
ICoWSwapSettlement public immutable settlement;
```


### domainSeparator

```solidity
bytes32 public immutable domainSeparator;
```


### weth

```solidity
IWETH public immutable weth;
```


### treasury

```solidity
address public immutable treasury;
```


## Functions
### constructor


```solidity
constructor(address settlement_, address treasury_);
```

### execute


```solidity
function execute(address[] calldata collections, uint[] calldata amounts, bytes calldata)
    external
    payable
    override
    returns (string memory);
```

## Structs
### Data

```solidity
struct Data {
    IERC20 sellToken;
    IERC20 buyToken;
    address receiver;
    uint sellAmount;
    uint buyAmount;
    uint32 validFrom;
    uint32 validTo;
    uint feeAmount;
    bytes meta;
}
```

