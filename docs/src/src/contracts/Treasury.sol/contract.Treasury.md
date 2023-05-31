# Treasury
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/Treasury.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), ERC1155Holder, [ITreasury](/src/interfaces/Treasury.sol/contract.ITreasury.md)

The Treasury will hold all assets.


## State Variables
### epochSweeps
An array of sweeps that map against the epoch iteration.


```solidity
mapping(uint => Sweep) public epochSweeps;
```


### floor
Holds our {FLOOR} and {WETH} contract references.


```solidity
FLOOR public floor;
```


### weth

```solidity
IWETH public weth;
```


### minSweepAmount
Store a minimum sweep amount that can be implemented, or excluded, as desired by
the DAO.


```solidity
uint public minSweepAmount;
```


### mercSweeper
Stores our Mercenary sweeper contract address


```solidity
IMercenarySweeper public mercSweeper;
```


### approvedSweepers
Stores a list of approved sweeper contracts


```solidity
mapping(address => bool) public approvedSweepers;
```


## Functions
### constructor

Set up our connection to the Treasury to ensure future calls only come from this
trusted source.


```solidity
constructor(address _authority, address _floor, address _weth) AuthorityControl(_authority);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_authority`|`address`|{AuthorityRegistry} contract address|
|`_floor`|`address`|Address of our {FLOOR}|
|`_weth`|`address`||


### mint

Allow FLOOR token to be minted. This should be called from the deposit method
internally, but a public method will allow a {TreasuryManager} to bypass this
and create additional FLOOR tokens if needed.


```solidity
function mint(uint amount) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of {FLOOR} tokens to be minted|


### _mint

Internal call to handle minting and event firing.


```solidity
function _mint(address recipient, uint amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The recipient of the {FLOOR} tokens|
|`amount`|`uint256`|The number of tokens to be minted|


### depositERC20

Allows an ERC20 token to be deposited and generates FLOOR tokens based on
the current determined value of FLOOR and the token.


```solidity
function depositERC20(address token, uint amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|ERC20 token address to be deposited|
|`amount`|`uint256`|The amount of the token to be deposited|


### depositERC721

Allows an ERC721 token to be deposited and generates FLOOR tokens based on
the current determined value of FLOOR and the token.


```solidity
function depositERC721(address token, uint tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|ERC721 token address to be deposited|
|`tokenId`|`uint256`|The ID of the ERC721 being deposited|


### depositERC1155

Allows an ERC1155 token(s) to be deposited and generates FLOOR tokens based on
the current determined value of FLOOR and the token.


```solidity
function depositERC1155(address token, uint tokenId, uint amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|ERC1155 token address to be deposited|
|`tokenId`|`uint256`|The ID of the ERC1155 being deposited|
|`amount`|`uint256`|The amount of the token to be deposited|


### withdraw

Allows an approved user to withdraw native token.


```solidity
function withdraw(address recipient, uint amount) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The user that will receive the native token|
|`amount`|`uint256`|The number of native tokens to withdraw|


### withdrawERC20

Allows an approved user to withdraw an ERC20 token from the vault.


```solidity
function withdrawERC20(address recipient, address token, uint amount) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The user that will receive the ERC20 tokens|
|`token`|`address`|ERC20 token address to be withdrawn|
|`amount`|`uint256`|The number of tokens to withdraw|


### withdrawERC721

Allows an approved user to withdraw an ERC721 token from the vault.


```solidity
function withdrawERC721(address recipient, address token, uint tokenId) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The user that will receive the ERC721 tokens|
|`token`|`address`|ERC721 token address to be withdrawn|
|`tokenId`|`uint256`|The ID of the ERC721 being withdrawn|


### withdrawERC1155

Allows an approved user to withdraw an ERC1155 token(s) from the vault.


```solidity
function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The user that will receive the ERC1155 tokens|
|`token`|`address`|ERC1155 token address to be withdrawn|
|`tokenId`|`uint256`|The ID of the ERC1155 being withdrawn|
|`amount`|`uint256`|The number of tokens to withdraw|


### processAction

Apply an action against the vault. If we need any tokens to be approved before the
action is called, then these are approved before our call and approval is removed
afterwards for 1155s.


```solidity
function processAction(address payable action, ActionApproval[] calldata approvals, bytes calldata data, uint linkedSweepEpoch)
    external
    onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`action`|`address payable`|Address of the action to apply|
|`approvals`|`ActionApproval[]`|Any tokens that need to be approved before actioning|
|`data`|`bytes`|Any bytes data that should be passed to the {IAction} execution function|
|`linkedSweepEpoch`|`uint256`||


### registerSweep

When an epoch ends, we have the ability to register a sweep against the {Treasury}
via an approved contract. This will store a DAO sweep that will need to be actioned
using the `sweepEpoch` function.


```solidity
function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts, TreasuryEnums.SweepType sweepType)
    external
    onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epoch`|`uint256`|The current epoch that the sweep is generated from|
|`collections`|`address[]`|The collections that will be swept|
|`amounts`|`uint256[]`|The amount of ETH to sweep against each collection|
|`sweepType`|`SweepType.TreasuryEnums`||


### sweepEpoch

Actions a sweep to be used against a contract that implements {ISweeper}. This
will fulfill the sweep and we then mark the sweep as completed.


```solidity
function sweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epochIndex`|`uint256`|The index of the `epochSweeps`|
|`sweeper`|`address`|The address of the sweeper contract to be used|
|`data`|`bytes`|Additional meta data to send to the sweeper|
|`mercSweep`|`uint256`||


### resweepEpoch

Checks if the Epoch grace period has expired. This gives the DAO 1 epoch to action
the sweep before allowing an external party to action on their behalf.
Sweep       Current
3           3           Not ended yet
3           4           Only DAO
3           5           5,000 FLOOR
If the grace period has ended, then a user that holds 5,000 FLOOR tokens can action
the sweep to take place.
Allows the DAO to resweep an already swept "Sweep" struct, using a contract that
implements {ISweeper}. This will fulfill the sweep again and keep the sweep marked
as completed.

*This should only be used if there was an unexpected issue with the initial
sweep that resulted in assets not being correctly acquired, but the epoch being
marked as swept.*


```solidity
function resweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) public onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`epochIndex`|`uint256`|The index of the `epochSweeps`|
|`sweeper`|`address`|The address of the sweeper contract to be used|
|`data`|`bytes`|Additional meta data to send to the sweeper|
|`mercSweep`|`uint256`||


### _sweepEpoch

Handles the logic to action a sweep.


```solidity
function _sweepEpoch(uint epochIndex, address sweeper, Sweep memory epochSweep, bytes calldata data, uint mercSweep) internal;
```

### setMercenarySweeper

Allows the mercenary sweeper contract to be updated.


```solidity
function setMercenarySweeper(address _mercSweeper) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mercSweeper`|`address`|the new {IMercenarySweeper} contract|


### approveSweeper

Allows a sweeper contract to be approved or uapproved. This must be done before
a contract can be referenced in the `sweepEpoch` and `resweepEpoch` calls.


```solidity
function approveSweeper(address _sweeper, bool _approved) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sweeper`|`address`|The address of the sweeper contract|
|`_approved`|`bool`|True to approve, False to unapprove|


### setMinSweepAmount

Allows us to set a minimum amount of ETH to sweep with, so that if the yield
allocated to the sweep is too low to be beneficial, then the DAO can stomache
the additional cost.


```solidity
function setMinSweepAmount(uint _minSweepAmount) external onlyRole(TREASURY_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minSweepAmount`|`uint256`|The minimum amount of ETH to sweep with|


### receive

Allow our contract to receive native tokens.


```solidity
receive() external payable;
```

