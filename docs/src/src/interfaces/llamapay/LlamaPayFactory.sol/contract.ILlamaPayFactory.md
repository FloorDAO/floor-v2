# ILlamaPayFactory
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/llamapay/LlamaPayFactory.sol)


## Functions
### INIT_CODEHASH


```solidity
function INIT_CODEHASH() external returns (bytes32);
```

### parameter


```solidity
function parameter() external returns (address);
```

### getLlamaPayContractCount


```solidity
function getLlamaPayContractCount() external returns (uint);
```

### getLlamaPayContractByIndex


```solidity
function getLlamaPayContractByIndex(uint) external returns (address);
```

### createLlamaPayContract

Create a new Llama Pay Streaming instance for `_token`

*Instances are created deterministically via CREATE2 and duplicate instances
will cause a revert.*


```solidity
function createLlamaPayContract(address _token) external returns (address llamaPayContract);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The ERC20 token address for which a Llama Pay contract should be deployed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`llamaPayContract`|`address`|The address of the newly created Llama Pay contract|


### getLlamaPayContractByToken

Query the address of the Llama Pay contract for `_token` and whether it is deployed


```solidity
function getLlamaPayContractByToken(address _token) external view returns (address predictedAddress, bool isDeployed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|An ERC20 token address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`predictedAddress`|`address`|The deterministic address where the llama pay contract will be deployed for `_token`|
|`isDeployed`|`bool`|Boolean denoting whether the contract is currently deployed|


