# MercenarySweeper
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/sweepers/Mercenary.sol)

**Inherits:**
[IMercenarySweeper](/src/interfaces/actions/Sweeper.sol/contract.IMercenarySweeper.md)

Acts as an interface to allow Optioned Mercenaries to be swept after a collection
addition war. This will take a flat amount and sweep as many as it can for the
amount provided, prioritised by discount first, then staking order (oldest first).

*This sweeper makes the assumption that only one collection and amount will
be passed through as this is used for the Collection Addition War which, at time
of writing, should only allow for a singular winner to be crowned.*


## State Variables
### newCollectionWarOptions
Contract reference to our active {NewCollectionWars} contract


```solidity
INewCollectionWarOptions public immutable newCollectionWarOptions;
```


## Functions
### constructor

Sets our immutable {NewCollectionWarOptions} contract reference and casts it's interface.


```solidity
constructor(address _newCollectionWarOptions);
```

### execute

Actions our Mercenary sweep.


```solidity
function execute(uint warIndex, uint amount) external payable override returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`warIndex`|`uint256`|The index of the war being executed|
|`amount`|`uint256`|The amount allocated to the transaction|


