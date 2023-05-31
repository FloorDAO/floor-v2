# VestingClaim
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/migrations/VestingClaim.sol)

**Inherits:**
Ownable

Handles the migration of remaining claimable FLOOR tokens. This will be a
slightly manual process as it requires the {RemainingVestingFloor} report
to be run before time to determine the amount of FLOOR tokens that should
be allocated, and to which addresses.


## State Variables
### FLOOR

```solidity
IFLOOR public immutable FLOOR;
```


### WETH

```solidity
IERC20 public immutable WETH;
```


### treasury

```solidity
ITreasury private immutable treasury;
```


### allocation

```solidity
mapping(address => uint) internal allocation;
```


## Functions
### constructor


```solidity
constructor(address _floor, address _weth, address _treasury);
```

### claim

Allows wallet to claim FLOOR. We multiply by 1e6 as we convert the FLOOR from
a WETH finney.


```solidity
function claim(address _to, uint _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|address The address that is claiming|
|`_amount`|`uint256`|uint256 The amount being claimed in FLOOR (18 decimals)|


### redeemableFor

View FLOOR claimable for address.


```solidity
function redeemableFor(address _address) public view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The wallet address to check allocation of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The amount of FLOOR tokens allocated and available to claim|


### setAllocation

Assign a range of FLOOR allocation to addresses.

*The token does not need to be transferred with this call as it is minted
at point of claim.*


```solidity
function setAllocation(address[] calldata _address, uint[] calldata _amount) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address[]`|The address made available for allocation claims|
|`_amount`|`uint256[]`|The amount of tokens allocated to the corresponding address|


