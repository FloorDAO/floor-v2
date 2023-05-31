# VeFloorStaking
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/staking/VeFloorStaking.sol)

**Inherits:**
[EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), ERC20, ERC20Permit, ERC20Votes, [IVeFloorStaking](/src/interfaces/staking/VeFloorStaking.sol/contract.IVeFloorStaking.md), [IVotable](/src/interfaces/tokens/Votable.sol/contract.IVotable.md)

The contract provides the following features: staking, delegation, farming
How lock period works:
- balances and voting power
- Lock min and max
- Add lock
- earlyWithdrawal
- penalty math

*Based on staked 1inch (St1inch :: 0x9A0C8Ff858d273f57072D714bca7411D717501D7)*


## State Variables
### LOCK_PERIODS
Set a list of locking periods that the user can lock for


```solidity
uint8[] public LOCK_PERIODS = [uint8(0), 4, 13, 26, 52, 78, 104];
```


### floor
Our FLOOR token


```solidity
IERC20 public immutable floor;
```


### treasury
Our internal contracts


```solidity
ITreasury public immutable treasury;
```


### newCollectionWars

```solidity
INewCollectionWars public newCollectionWars;
```


### sweepWars

```solidity
ISweepWars public sweepWars;
```


### earlyWithdrawFeeExemptions
Allow some addresses to be exempt from early withdraw fees


```solidity
mapping(address => bool) public earlyWithdrawFeeExemptions;
```


### depositors
Map our Depositor index against a user


```solidity
mapping(address => Depositor) public depositors;
```


### _ONE_E9

```solidity
uint internal constant _ONE_E9 = 1e9;
```


### totalDeposits

```solidity
uint public totalDeposits;
```


### emergencyExit

```solidity
bool public emergencyExit;
```


### maxLossRatio

```solidity
uint public maxLossRatio;
```


### minLockPeriodRatio

```solidity
uint public minLockPeriodRatio;
```


### feeReceiver

```solidity
address public feeReceiver;
```


## Functions
### constructor

Initializes the contract


```solidity
constructor(IERC20 floor_, address treasury_) ERC20('veFLOOR', 'veFLOOR') ERC20Permit('veFLOOR');
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`floor_`|`IERC20`|The token to be staked|
|`treasury_`|`address`|The treasury contract address|


### setFeeReceiver

Sets the new contract that would recieve early withdrawal fees


```solidity
function setFeeReceiver(address feeReceiver_) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeReceiver_`|`address`|The receiver contract address|


### setMaxLossRatio

Sets the maximum allowed loss ratio for early withdrawal. If the ratio is not met, actual is more than allowed,
then early withdrawal will revert.
Example: maxLossRatio = 90% and 1000 staked 1inch tokens means that a user can execute early withdrawal only
if his loss is less than or equals 90% of his stake, which is 900 tokens. Thus, if a user loses 900 tokens he is allowed
to do early withdrawal and not if the loss is greater.


```solidity
function setMaxLossRatio(uint maxLossRatio_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxLossRatio_`|`uint256`|The maximum loss allowed (9 decimals).|


### setMinLockPeriodRatio

Sets the minimum allowed lock period ratio for early withdrawal. If the ratio is not met, actual is more than allowed,
then early withdrawal will revert.


```solidity
function setMinLockPeriodRatio(uint minLockPeriodRatio_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minLockPeriodRatio_`|`uint256`|The maximum loss allowed (9 decimals).|


### setEmergencyExit

Sets the emergency exit mode. In emergency mode any stake may withdraw its stake regardless of lock.
The mode is intended to use only for migration to a new version of staking contract.


```solidity
function setEmergencyExit(bool emergencyExit_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergencyExit_`|`bool`|set `true` to enter emergency exit mode and `false` to return to normal operations|


### votingPowerOf

Gets the voting power of the provided account


```solidity
function votingPowerOf(address account) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of an account to get voting power for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|votingPower The voting power available at the current epoch|


### votingPowerAt

Gets the voting power of the provided account at a specific epoch


```solidity
function votingPowerAt(address account, uint epoch) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of an account to get voting power for|
|`epoch`|`uint256`|The epoch at which to check the user's voting power|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|votingPower The voting power available at the epoch|


### votingPowerOfAt

Gets the voting power of the provided account at a specific epoch


```solidity
function votingPowerOfAt(address account, uint88 amount, uint epoch) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of an account to get voting power for|
|`amount`|`uint88`|The amount of voting power the account has|
|`epoch`|`uint256`|The epoch at which to check the user's voting power|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|votingPower The voting power available at the epoch|


### deposit

Stakes given amount and locks it for the given duration


```solidity
function deposit(uint amount, uint epochs) external;
```

### depositWithPermit

Stakes given amount and locks it for the given duration with permit


```solidity
function depositWithPermit(uint amount, uint epochs, bytes calldata permit) external;
```

### depositFor

Stakes given amount on behalf of provided account without locking or extending lock


```solidity
function depositFor(address account, uint amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to stake for|
|`amount`|`uint256`|The amount to stake|


### depositForWithPermit

Stakes given amount on behalf of provided account without locking or extending
lock with permit.


```solidity
function depositForWithPermit(address account, uint amount, bytes calldata permit) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to stake for|
|`amount`|`uint256`|The amount to stake|
|`permit`|`bytes`|Permit given by the caller|


### _deposit


```solidity
function _deposit(address account, uint amount, uint epochs) private;
```

### earlyWithdraw

Withdraw stake before lock period expires at the cost of losing part of a stake.
The stake loss is proportional to the time passed from the maximum lock period to the lock expiration and voting power.
The more time is passed the less would be the loss.
Formula to calculate return amount = (deposit - voting power)) / 0.95


```solidity
function earlyWithdraw(uint minReturn, uint maxLoss) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minReturn`|`uint256`|The minumum amount of stake acceptable for return. If actual amount is less then the transaction is reverted|
|`maxLoss`|`uint256`|The maximum amount of loss acceptable. If actual loss is bigger then the transaction is reverted|


### earlyWithdrawTo

Withdraw stake before lock period expires at the cost of losing part of a stake to the specified account
The stake loss is proportional to the time passed from the maximum lock period to the lock expiration and voting power.
The more time is passed the less would be the loss.
Formula to calculate return amount = (deposit - voting power)) / 0.95


```solidity
function earlyWithdrawTo(address to, uint minReturn, uint maxLoss) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The account to withdraw the stake to|
|`minReturn`|`uint256`|The minumum amount of stake acceptable for return. If actual amount is less then the transaction is reverted|
|`maxLoss`|`uint256`|The maximum amount of loss acceptable. If actual loss is bigger then the transaction is reverted|


### earlyWithdrawLoss

Gets the loss amount if the staker do early withdrawal at the current block


```solidity
function earlyWithdrawLoss(address account) external view returns (uint loss, uint ret, bool canWithdraw);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to calculate early withdrawal loss for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`loss`|`uint256`|The loss amount|
|`ret`|`uint256`|The return amount|
|`canWithdraw`|`bool`|True if the staker can withdraw without penalty, false otherwise|


### _earlyWithdrawLoss


```solidity
function _earlyWithdrawLoss(address, uint depAmount, uint stBalance) private pure returns (uint loss, uint ret);
```

### withdraw

Withdraws stake if lock period expired


```solidity
function withdraw() external;
```

### withdrawTo

Withdraws stake if lock period expired to the given address


```solidity
function withdrawTo(address to) public;
```

### _withdraw

Handles our internal logic to process a withdrawal for a depositor.


```solidity
function _withdraw(Depositor memory depositor, uint balance) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor`|`Depositor`|The structure for the user making the withdrawal|
|`balance`|`uint256`|The amount that the user is trying to withdraw|


### setVotingContracts

Allows our voting contract addresses to be updated.


```solidity
function setVotingContracts(address _newCollectionWars, address _sweepWars) external onlyOwner;
```

### rescueFunds

Retrieves funds from the contract in emergency situations


```solidity
function rescueFunds(IERC20 token, uint amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The token to retrieve|
|`amount`|`uint256`|The amount of funds to transfer|


### isExemptFromEarlyWithdrawFees

Checks if an address is exempt from having to pay early withdrawal fees.


```solidity
function isExemptFromEarlyWithdrawFees(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address of the account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool True if the user is exempt from early fees, false if not|


### addEarlyWithdrawFeeExemption

Allows an account to be exempted from paying early withdraw fees.


```solidity
function addEarlyWithdrawFeeExemption(address account, bool exempt) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to update|
|`exempt`|`bool`|If the account is to be exempt from fees|


### approve


```solidity
function approve(address, uint) public pure override (IERC20, ERC20) returns (bool);
```

### transfer


```solidity
function transfer(address, uint) public pure override (IERC20, ERC20) returns (bool);
```

### transferFrom


```solidity
function transferFrom(address, address, uint) public pure override (IERC20, ERC20) returns (bool);
```

### increaseAllowance


```solidity
function increaseAllowance(address, uint) public pure override returns (bool);
```

### decreaseAllowance


```solidity
function decreaseAllowance(address, uint) public pure override returns (bool);
```

### _afterTokenTransfer


```solidity
function _afterTokenTransfer(address from, address to, uint amount) internal override (ERC20, ERC20Votes);
```

### _mint


```solidity
function _mint(address to, uint amount) internal override (ERC20, ERC20Votes);
```

### _burn


```solidity
function _burn(address account, uint amount) internal override (ERC20, ERC20Votes);
```

## Events
### EmergencyExitSet

```solidity
event EmergencyExitSet(bool status);
```

### MaxLossRatioSet

```solidity
event MaxLossRatioSet(uint ratio);
```

### MinLockPeriodRatioSet

```solidity
event MinLockPeriodRatioSet(uint ratio);
```

### FeeReceiverSet

```solidity
event FeeReceiverSet(address receiver);
```

### Deposit

```solidity
event Deposit(address account, uint amount);
```

### Withdraw

```solidity
event Withdraw(address sender, uint amount);
```

## Errors
### ApproveDisabled

```solidity
error ApproveDisabled();
```

### TransferDisabled

```solidity
error TransferDisabled();
```

### UnlockTimeHasNotCome

```solidity
error UnlockTimeHasNotCome();
```

### StakeUnlocked

```solidity
error StakeUnlocked();
```

### MinLockPeriodRatioNotReached

```solidity
error MinLockPeriodRatioNotReached();
```

### MinReturnIsNotMet

```solidity
error MinReturnIsNotMet();
```

### MaxLossIsNotMet

```solidity
error MaxLossIsNotMet();
```

### MaxLossOverflow

```solidity
error MaxLossOverflow();
```

### LossIsTooBig

```solidity
error LossIsTooBig();
```

### RescueAmountIsTooLarge

```solidity
error RescueAmountIsTooLarge();
```

### ExpBaseTooBig

```solidity
error ExpBaseTooBig();
```

### ExpBaseTooSmall

```solidity
error ExpBaseTooSmall();
```

### DepositsDisabled

```solidity
error DepositsDisabled();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

