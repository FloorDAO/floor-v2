# IVeFLOOR
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/tokens/VeFloor.sol)

Vote Escrow ERC20 Token Interface.
The veFloor token is heavily influenced by the {VeJoeToken} token:
https://snowtrace.io/address/0x3cabf341943Bc8466245e4d6F1ae0f8D071a1456#code

Interface of a ERC20 token used for vote escrow. Notice that transfers and
allowances are disabled.


## Functions
### name

*Returns the name of the token.*


```solidity
function name() external view returns (string memory);
```

### symbol

*Returns the symbol of the token, usually a shorter version of the
name.*


```solidity
function symbol() external view returns (string memory);
```

### totalSupply

*Returns the amount of tokens in existence.*


```solidity
function totalSupply() external view returns (uint);
```

### balanceOf

*Returns the amount of tokens owned by `account`.*


```solidity
function balanceOf(address account) external view returns (uint);
```

### mint

Creates `_amount` token to `_to`. Must only be called by the owner.


```solidity
function mint(address _to, uint _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address that will receive the mint|
|`_amount`|`uint256`|The amount to be minted|


### burnFrom

Destroys `_amount` tokens from `_from`. Callable only by the owner (VeJoeStaking).


```solidity
function burnFrom(address _from, uint _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address that will burn tokens|
|`_amount`|`uint256`|The amount to be burned|


