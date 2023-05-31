# FLOOR
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/tokens/Floor.sol)

**Inherits:**
[AuthorityControl](/src/contracts/authorities/AuthorityControl.sol/contract.AuthorityControl.md), ERC20, ERC20Burnable, ERC20Permit, [IFLOOR](/src/interfaces/tokens/Floor.sol/contract.IFLOOR.md)

Sets up our FLOOR ERC20 token.


## Functions
### constructor

Sets up our ERC20 token.


```solidity
constructor(address _authority) ERC20('Floor', 'FLOOR') ERC20Permit('Floor') AuthorityControl(_authority);
```

### mint

Allows a `FLOOR_MANAGER` to mint additional FLOOR tokens.


```solidity
function mint(address to, uint amount) public onlyRole(FLOOR_MANAGER);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient of the tokens|
|`amount`|`uint256`|Amount of tokens to be minted|


