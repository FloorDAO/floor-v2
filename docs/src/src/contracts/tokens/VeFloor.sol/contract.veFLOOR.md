# veFLOOR
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/tokens/VeFloor.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), [IVeFLOOR](/src/interfaces/tokens/VeFloor.sol/contract.IVeFLOOR.md)

When a user stakes their FLOOR token in the {VeFloorStaking} contract, they will
receive a 1:1 {veFLOOR} token in return.
The veFloor token is heavily influenced by the {VeJoeToken} token:
https://snowtrace.io/address/0x3cabf341943Bc8466245e4d6F1ae0f8D071a1456#code


## State Variables
### _balances
Monitor balances held by users


```solidity
mapping(address => uint) private _balances;
```


### _totalSupply
Hold the total token supply


```solidity
uint private _totalSupply;
```


### _name
Metadata: Name


```solidity
string private _name;
```


### _symbol
Metadata: Symbol


```solidity
string private _symbol;
```


## Functions
### constructor

Sets the values for {name} and {symbol}.
The default value of {decimals} is 18. To select a different value for
{decimals} you should overload it.
Both of these values are immutable: they can only be set once during
construction.


```solidity
constructor(string memory name_, string memory symbol_, address _authority) AuthorityControl(_authority);
```

### name

Returns the name of the token.


```solidity
function name() public view virtual returns (string memory);
```

### symbol

Returns the symbol of the token, usually a shorter version of the
name.


```solidity
function symbol() public view virtual returns (string memory);
```

### decimals

Returns the number of decimals used to get its user representation.
For example, if `decimals` equals `2`, a balance of `505` tokens should
be displayed to a user as `5.05` (`505 / 10 ** 2`).
Tokens usually opt for a value of 18, imitating the relationship between
Ether and Wei. This is the value {ERC20} uses, unless this function is
overridden;
NOTE: This information is only used for _display_ purposes: it in
no way affects any of the arithmetic of the contract, including
{IERC20-balanceOf} and {IERC20-transfer}.


```solidity
function decimals() public view virtual returns (uint8);
```

### totalSupply

Returns the amount of tokens in existence.


```solidity
function totalSupply() public view virtual override returns (uint);
```

### balanceOf

Returns the amount of tokens owned by `account`.


```solidity
function balanceOf(address account) public view virtual override returns (uint);
```

### mint

Creates `_amount` token to `_to`. Must only be called by the owner (VeJoeStaking).


```solidity
function mint(address _to, uint _amount) external onlyRole(FLOOR_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address that will receive the mint|
|`_amount`|`uint256`|The amount to be minted|


### _mint

Creates `amount` tokens and assigns them to `account`, increasing the total supply.
Emits a {Transfer} event with `from` set to the zero address.
Requirements:
- `account` cannot be the zero address.


```solidity
function _mint(address account, uint amount) internal virtual;
```

### burnFrom

Destroys `_amount` tokens from `_from`. Callable only by the owner (VeJoeStaking).


```solidity
function burnFrom(address _from, uint _amount) external onlyRole(FLOOR_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address that will burn tokens|
|`_amount`|`uint256`|The amount to be burned|


### _burn

Destroys `amount` tokens from `account`, reducing the
total supply.
Emits a {Transfer} event with `to` set to the zero address.
Requirements:
- `account` cannot be the zero address.
- `account` must have at least `amount` tokens.


```solidity
function _burn(address account, uint amount) internal virtual;
```

### _beforeTokenOperation

Hook that is called before any minting and burning.


```solidity
function _beforeTokenOperation(address from, address to, uint amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|the account transferring tokens|
|`to`|`address`|the account receiving tokens|
|`amount`|`uint256`|the amount being minted or burned|


### _afterTokenOperation

Hook that is called after any minting and burning.


```solidity
function _afterTokenOperation(address _account, uint _newBalance) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|the account being affected|
|`_newBalance`|`uint256`|the new balance of `account` after minting/burning|


## Events
### Burn
Emitted when `value` tokens are burned and minted


```solidity
event Burn(address indexed account, uint value);
```

### Mint

```solidity
event Mint(address indexed beneficiary, uint value);
```

