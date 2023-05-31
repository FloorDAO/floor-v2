# VaultXToken
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/tokens/VaultXToken.sol)

**Inherits:**
ERC20Upgradeable, [IVaultXToken](/src/interfaces/tokens/VaultXToken.sol/contract.IVaultXToken.md), OwnableUpgradeable

**Author:**
Roger Wu (https://github.com/roger-wu)
A mintable ERC20 token that allows anyone to pay and distribute a target token
to token holders as dividends and allows token holders to withdraw their dividends.

VaultXToken - (Based on Dividend Token)


## State Variables
### target
The ERC20 token that will be distributed as rewards


```solidity
IERC20 public target;
```


### magnitude

```solidity
uint internal constant magnitude = 2 ** 128;
```


### magnifiedRewardPerShare

```solidity
uint internal magnifiedRewardPerShare;
```


### magnifiedRewardCorrections
About dividendCorrection:
If the token balance of a `_user` is never changed, the dividend of `_user` can be computed with:
`dividendOf(_user) = dividendPerShare * balanceOf(_user)`.
When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
`dividendOf(_user)` should not be changed, but the computed value of
`dividendPerShare * balanceOf(_user)` is changed.
To keep the `dividendOf(_user)` unchanged, we add a correction term:
`dividendOf(_user) = dividendPerShare * balanceOf(_user) + dividendCorrectionOf(_user)`,
where `dividendCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
`dividendCorrectionOf(_user) = dividendPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
So now `dividendOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.


```solidity
mapping(address => int) internal magnifiedRewardCorrections;
```


### withdrawnRewards

```solidity
mapping(address => uint) internal withdrawnRewards;
```


### staking
Staking contract


```solidity
IVeFloorStaking public staking;
```


## Functions
### initialize

Set up our required parameters.


```solidity
function initialize(address _target, address _staking, string memory _name, string memory _symbol) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_target`|`address`|ERC20 contract address used for reward distribution|
|`_staking`|`address`|Address of the {VeFloorStaking} contract|
|`_name`|`string`|Name of our xToken|
|`_symbol`|`string`|Symbol of our xToken|


### transfer

Transfers the token from the called to the recipient.


```solidity
function transfer(address recipient, uint amount) public virtual override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Recipient of the tokens|
|`amount`|`uint256`|Amount of token to be sent TODO: Does this want to be disabled?|


### transferFrom

*See {IERC20-transferFrom}.
Emits an {Approval} event indicating the updated allowance. This is not
required by the EIP. See the note at the beginning of {ERC20}.
Requirements:
- `sender` and `recipient` cannot be the zero address.
- `sender` must have a balance of at least `amount`.
- the caller must have allowance for ``sender``'s tokens of at least
`amount`.*


```solidity
function transferFrom(address sender, address recipient, uint amount) public virtual override returns (bool);
```

### mint

Allows the owner of the xToken (the parent vault) to mint.


```solidity
function mint(address account, uint amount) public virtual onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Recipient of the tokens|
|`amount`|`uint256`|Amount of token to be minted|


### burnFrom

Destroys `amount` tokens from `account`, without deducting from the caller's
allowance. Dangerous.
See {ERC20-_burn} and {ERC20-allowance}.


```solidity
function burnFrom(address account, uint amount) public virtual onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address that will have their tokens burned|
|`amount`|`uint256`|Amount of token to be burned|


### distributeRewards

Distributes target to token holders as dividends.
It emits the `RewardsDistributed` event if the amount of received target is greater than 0.
About undistributed target tokens:
In each distribution, there is a small amount of target not distributed, the magnified amount
of which is `(amount * magnitude) % totalSupply()`. With a well-chosen `magnitude`, the
amount of undistributed target (de-magnified) in a distribution can be less than 1 wei.
We can actually keep track of the undistributed target in a distribution and try to distribute
it in the next distribution, but keeping track of such data on-chain costs much more than
the saved target, so we don't do that.

*It reverts if the total supply of tokens is 0.*


```solidity
function distributeRewards(uint amount) external virtual onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of rewards to distribute amongst holders|


### withdrawReward

Withdraws the target distributed to the sender.

*It emits a `RewardWithdrawn` event if the amount of withdrawn target is greater than 0.*


```solidity
function withdrawReward(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User to withdraw rewards to|


### dividendOf

View the amount of dividend in wei that an address can withdraw.


```solidity
function dividendOf(address _owner) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The address of a token holder|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of dividend in wei that `_owner` can withdraw|


### withdrawableRewardOf

View the amount of dividend in wei that an address can withdraw.


```solidity
function withdrawableRewardOf(address _owner) internal view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The address of a token holder|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of dividend in wei that `_owner` can withdraw|


### withdrawnRewardOf

View the amount of dividend in wei that an address has withdrawn.


```solidity
function withdrawnRewardOf(address _owner) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The address of a token holder|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of dividend in wei that `_owner` has withdrawn|


### accumulativeRewardOf

View the amount of dividend in wei that an address has earned in total.


```solidity
function accumulativeRewardOf(address _owner) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|The address of a token holder|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of dividend in wei that `_owner` has earned in total|


### _transfer

Internal function that transfer tokens from one address to another.
Update magnifiedRewardCorrections to keep dividends unchanged.


```solidity
function _transfer(address from, address to, uint value) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address to transfer from|
|`to`|`address`|The address to transfer to|
|`value`|`uint256`|The amount to be transferred|


### _mint

Internal function that mints tokens to an account.
Update magnifiedRewardCorrections to keep dividends unchanged.


```solidity
function _mint(address account, uint value) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account that will receive the created tokens.|
|`value`|`uint256`|The amount that will be created.|


### _burn

Internal function that burns an amount of the token of a given account.
Update magnifiedRewardCorrections to keep dividends unchanged.


```solidity
function _burn(address account, uint value) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account whose tokens will be burnt.|
|`value`|`uint256`|The amount that will be burnt.|


