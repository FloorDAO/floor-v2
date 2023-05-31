# MigrateFloorToken
[Git Source](https://github.com/FloorDAO/floor-v2/blob/445b96358cc205e432e359914c1681c0f44048b0/src/contracts/migrations/MigrateFloorToken.sol)

**Inherits:**
[IMigrateFloorToken](/src/interfaces/migrations/MigrateFloorToken.sol/contract.IMigrateFloorToken.md)

Burns FLOOR v1 tokens for FLOOR v2 tokens. We have a list of the defined
V1 tokens in our test suites that should be accept. These include a, g and
s floor variants.
This should provide a 1:1 V1 burn -> V2 mint of tokens.
The balance of all tokens will be attempted to be migrated, so 4 full approvals
should be made prior to calling this contract function.


## State Variables
### MIGRATED_TOKENS
List of FLOOR V1 token contract addresses on mainnet


```solidity
address[] private MIGRATED_TOKENS = [
    0xf59257E961883636290411c11ec5Ae622d19455e,
    0x0C3983165E9BcE0a9Bb43184CC4eEBb26dce48fA,
    0xb1Cc59Fc717b8D4783D41F952725177298B5619d,
    0x164AFe96912099543BC2c48bb9358a095Db8e784
];
```


### newFloor
Contract address of new FLOOR V2 token


```solidity
address public immutable newFloor;
```


## Functions
### constructor

Stores the deployed V2 FLOOR token contract address.


```solidity
constructor(address _newFloor);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newFloor`|`address`|Address of our deployed FLOOR V2 token|


### upgradeFloorToken

Iterates through existing V1 FLOOR tokens and mints them into FLOOR V2 tokens. The existing
V1 tokens aren't burnt, but are just left in the existing wallet.

*For the gFloor token, we need to update the decimal accuracy from 9 to 18.*


```solidity
function upgradeFloorToken() external override;
```

## Events
### FloorMigrated
Emitted when tokens have been migrated to a user


```solidity
event FloorMigrated(address caller, uint amount);
```

