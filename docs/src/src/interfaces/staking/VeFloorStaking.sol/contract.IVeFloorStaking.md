# IVeFloorStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/interfaces/staking/VeFloorStaking.sol)


## Functions
### LOCK_PERIODS

Set a list of locking periods that the user can lock for


```solidity
function LOCK_PERIODS(uint) external returns (uint8);
```

### earlyWithdrawFeeExemptions


```solidity
function earlyWithdrawFeeExemptions(address) external returns (bool);
```

### depositors


```solidity
function depositors(address) external returns (uint160, uint8, uint88);
```

### totalDeposits


```solidity
function totalDeposits() external returns (uint);
```

### emergencyExit


```solidity
function emergencyExit() external returns (bool);
```

### maxLossRatio


```solidity
function maxLossRatio() external returns (uint);
```

### minLockPeriodRatio


```solidity
function minLockPeriodRatio() external returns (uint);
```

### feeReceiver


```solidity
function feeReceiver() external returns (address);
```

### setFeeReceiver


```solidity
function setFeeReceiver(address feeReceiver_) external;
```

### setMaxLossRatio


```solidity
function setMaxLossRatio(uint maxLossRatio_) external;
```

### setMinLockPeriodRatio


```solidity
function setMinLockPeriodRatio(uint minLockPeriodRatio_) external;
```

### setEmergencyExit


```solidity
function setEmergencyExit(bool emergencyExit_) external;
```

### votingPowerAt


```solidity
function votingPowerAt(address account, uint epoch) external view returns (uint);
```

### votingPowerOfAt


```solidity
function votingPowerOfAt(address account, uint88 amount, uint epoch) external view returns (uint);
```

### deposit


```solidity
function deposit(uint amount, uint epochs) external;
```

### depositWithPermit


```solidity
function depositWithPermit(uint amount, uint epochs, bytes calldata permit) external;
```

### depositFor


```solidity
function depositFor(address account, uint amount) external;
```

### depositForWithPermit


```solidity
function depositForWithPermit(address account, uint amount, bytes calldata permit) external;
```

### earlyWithdraw


```solidity
function earlyWithdraw(uint minReturn, uint maxLoss) external;
```

### earlyWithdrawTo


```solidity
function earlyWithdrawTo(address to, uint minReturn, uint maxLoss) external;
```

### earlyWithdrawLoss


```solidity
function earlyWithdrawLoss(address account) external view returns (uint loss, uint ret, bool canWithdraw);
```

### withdraw


```solidity
function withdraw() external;
```

### withdrawTo


```solidity
function withdrawTo(address to) external;
```

### isExemptFromEarlyWithdrawFees


```solidity
function isExemptFromEarlyWithdrawFees(address account) external view returns (bool);
```

### addEarlyWithdrawFeeExemption


```solidity
function addEarlyWithdrawFeeExemption(address account, bool exempt) external;
```

