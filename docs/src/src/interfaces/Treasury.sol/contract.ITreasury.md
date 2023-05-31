# ITreasury
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/Treasury.sol)

*The Treasury will hold all assets.*


## Functions
### mint

Allow FLOOR token to be minted. This should be called from the deposit method
internally, but a public method will allow a {TreasuryManager} to bypass this
and create additional FLOOR tokens if needed.

*We only want to do this on creation and for inflation. Have a think on how
we can implement this!*


```solidity
function mint(uint amount) external;
```

### depositERC20

Allows an ERC20 token to be deposited and generates FLOOR tokens based on
the current determined value of FLOOR and the token.


```solidity
function depositERC20(address token, uint amount) external;
```

### depositERC721

Allows an ERC721 token to be deposited and generates FLOOR tokens based on
the current determined value of FLOOR and the token.


```solidity
function depositERC721(address token, uint tokenId) external;
```

### depositERC1155

Allows an ERC1155 token(s) to be deposited and generates FLOOR tokens based on
the current determined value of FLOOR and the token.


```solidity
function depositERC1155(address token, uint tokenId, uint amount) external;
```

### withdraw

Allows an approved user to withdraw native token.


```solidity
function withdraw(address recipient, uint amount) external;
```

### withdrawERC20

Allows an approved user to withdraw and ERC20 token from the vault.


```solidity
function withdrawERC20(address recipient, address token, uint amount) external;
```

### withdrawERC721

Allows an approved user to withdraw and ERC721 token from the vault.


```solidity
function withdrawERC721(address recipient, address token, uint tokenId) external;
```

### withdrawERC1155

Allows an approved user to withdraw an ERC1155 token(s) from the vault.


```solidity
function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external;
```

### sweepEpoch

..


```solidity
function sweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) external;
```

### resweepEpoch

..


```solidity
function resweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) external;
```

### registerSweep

..


```solidity
function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts, TreasuryEnums.SweepType sweepType) external;
```

### minSweepAmount

..


```solidity
function minSweepAmount() external returns (uint);
```

### setMercenarySweeper

..


```solidity
function setMercenarySweeper(address _mercSweeper) external;
```

## Events
### Deposit
*When native network token is withdrawn from the Treasury*


```solidity
event Deposit(uint amount);
```

### DepositERC20
*When an ERC20 is depositted into the vault*


```solidity
event DepositERC20(address token, uint amount);
```

### DepositERC721
*When an ERC721 is depositted into the vault*


```solidity
event DepositERC721(address token, uint tokenId);
```

### DepositERC1155
*When an ERC1155 is depositted into the vault*


```solidity
event DepositERC1155(address token, uint tokenId, uint amount);
```

### Withdraw
*When native network token is withdrawn from the Treasury*


```solidity
event Withdraw(uint amount, address recipient);
```

### WithdrawERC20
*When an ERC20 token is withdrawn from the Treasury*


```solidity
event WithdrawERC20(address token, uint amount, address recipient);
```

### WithdrawERC721
*When an ERC721 token is withdrawn from the Treasury*


```solidity
event WithdrawERC721(address token, uint tokenId, address recipient);
```

### WithdrawERC1155
*When an ERC1155 is withdrawn from the vault*


```solidity
event WithdrawERC1155(address token, uint tokenId, uint amount, address recipient);
```

### FloorMinted
*When FLOOR is minted*


```solidity
event FloorMinted(uint amount);
```

### ActionProcessed
*When a {Treasury} action is processed*


```solidity
event ActionProcessed(address action, bytes data);
```

### SweepRegistered
*When a sweep is registered against an epoch*


```solidity
event SweepRegistered(uint epochIndex);
```

### SweepAction
*When an action is assigned to a sweep epoch*


```solidity
event SweepAction(uint sweepEpoch);
```

### EpochSwept
*When an epoch is swept*


```solidity
event EpochSwept(uint epochIndex);
```

## Structs
### Sweep
Stores data that allows the Treasury to action a sweep.


```solidity
struct Sweep {
    TreasuryEnums.SweepType sweepType;
    address[] collections;
    uint[] amounts;
    bool completed;
    string message;
}
```

### ActionApproval
The data structure format that will be mapped against to define a token
approval request.


```solidity
struct ActionApproval {
    TreasuryEnums.ApprovalType _type;
    address assetContract;
    uint tokenId;
    uint amount;
}
```

