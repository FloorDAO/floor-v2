# ILlamaPay
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/interfaces/llamapay/LlamaPay.sol)


## Functions
### streamToStart


```solidity
function streamToStart(bytes32) external returns (uint);
```

### payers


```solidity
function payers(address) external returns (Payer memory);
```

### balances


```solidity
function balances(address) external returns (uint);
```

### token


```solidity
function token() external returns (IERC20);
```

### DECIMALS_DIVISOR


```solidity
function DECIMALS_DIVISOR() external returns (uint);
```

### getStreamId


```solidity
function getStreamId(address from, address to, uint216 amountPerSec) external pure returns (bytes32);
```

### createStream


```solidity
function createStream(address to, uint216 amountPerSec) external;
```

### createStreamWithReason


```solidity
function createStreamWithReason(address to, uint216 amountPerSec, string calldata reason) external;
```

### withdrawable


```solidity
function withdrawable(address from, address to, uint216 amountPerSec)
    external
    view
    returns (uint withdrawableAmount, uint lastUpdate, uint owed);
```

### withdraw


```solidity
function withdraw(address from, address to, uint216 amountPerSec) external;
```

### cancelStream


```solidity
function cancelStream(address to, uint216 amountPerSec) external;
```

### pauseStream


```solidity
function pauseStream(address to, uint216 amountPerSec) external;
```

### modifyStream


```solidity
function modifyStream(address oldTo, uint216 oldAmountPerSec, address to, uint216 amountPerSec) external;
```

### deposit


```solidity
function deposit(uint amount) external;
```

### depositAndCreate


```solidity
function depositAndCreate(uint amountToDeposit, address to, uint216 amountPerSec) external;
```

### depositAndCreateWithReason


```solidity
function depositAndCreateWithReason(uint amountToDeposit, address to, uint216 amountPerSec, string calldata reason) external;
```

### withdrawPayer


```solidity
function withdrawPayer(uint amount) external;
```

### withdrawPayerAll


```solidity
function withdrawPayerAll() external;
```

### getPayerBalance


```solidity
function getPayerBalance(address payerAddress) external view returns (int);
```

## Structs
### Payer

```solidity
struct Payer {
    uint40 lastPayerUpdate;
    uint216 totalPaidPerSec;
}
```

