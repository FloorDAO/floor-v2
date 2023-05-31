# UniswapV3PricingExecutor
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/pricing/UniswapV3PricingExecutor.sol)

**Inherits:**
[IBasePricingExecutor](/src/interfaces/pricing/BasePricingExecutor.sol/contract.IBasePricingExecutor.md)

The Uniswap pricing executor will query either a singular token or multiple
tokens in a peripheral multicall to return a price of TOKEN -> ETH. We will
need to calculate the pool address for TOKEN:ETH and then find the spot
price.
Multicall documentation can be found here:
https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol
We will also find the spot price of the FLOOR:ETH pool so that we can calculate
TOKEN -> FLOOR via ETH as an interim.


## State Variables
### uniswapV3PoolFactory
Maintain an immutable address of the Uniswap V3 Pool Factory contract


```solidity
IUniswapV3Factory public immutable uniswapV3PoolFactory;
```


### floor
The contract address of the Floor token


```solidity
address public immutable floor;
```


### WETH
The WETH contract address used for price mappings


```solidity
address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


### poolAddresses
Keep a cache of our pool addresses for gas optimisation


```solidity
mapping(address => address) internal poolAddresses;
```


### floorPriceCache
Keep a cache of our latest price mappings


```solidity
mapping(address => uint) internal floorPriceCache;
```


## Functions
### constructor

Set our immutable contract addresses.

*Mainnet Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984*


```solidity
constructor(address _poolFactory, address _floor);
```

### name

Name of the pricing executor; this should be unique from other pricing executors.


```solidity
function name() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|string Pricing Executor name|


### getETHPrice

Gets our live price of a token to ETH.


```solidity
function getETHPrice(address token) external returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token to find price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The ETH value of a singular token|


### getETHPrices

Gets our live prices of multiple tokens to ETH.


```solidity
function getETHPrices(address[] memory tokens) external returns (uint[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`address[]`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|uint[] The ETH values of a singular token, mapping to passed token index|


### getFloorPrice

Gets a live mapped price of a token to FLOOR, returned in the correct decimal
count for the target token.
We get the latest price of not only the requested token, but also for the
FLOOR token. We can then determine the amount of returned token based on
live price values from Token -> ETH -> FLOOR.


```solidity
function getFloorPrice(address token) external returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token to find price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint The FLOOR value of a singular token|


### getFloorPrices

Gets a live mapped price of multiple tokens to FLOOR.


```solidity
function getFloorPrices(address[] memory tokens) external returns (uint[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`address[]`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|uint[] The FLOOR values of tokens passed|


### getLatestFloorPrice

Gets the latest Floor price returned. This won't make an external call and should
only be used in reference when live data is not required.


```solidity
function getLatestFloorPrice(address token) external view returns (uint);
```

### getLiquidity

Retrieves the amount of WETH held in the Uniswap pool.


```solidity
function getLiquidity(address token) external returns (uint);
```

### _calculateFloorPrice

This helper function allows us to return the amount of FLOOR a user would receive
for 1 token, returned in the decimal accuracy of the FLOOR token.


```solidity
function _calculateFloorPrice(uint tokenPrice, uint floorPrice) internal pure returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenPrice`|`uint256`|Spot price of passed token contract for 1 token|
|`floorPrice`|`uint256`|Spot price of FLOOR for 1 token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of FLOOR returned if one token sold|


### _poolAddress

Returns the pool address for a given pair of tokens and a fee, or address 0 if
it does not exist. The secondary token will always be WETH for our requirements,
so this is just passed in from our contract constant.
For gas optimisation, we cache the pool address that is calculated, to prevent
subsequent external calls being required.


```solidity
function _poolAddress(address token) internal returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token contract to find the ETH pool of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address The UniSwap ETH:token pool|


### _getPrice

Retrieves the token price in WETH from a Uniswap pool.


```solidity
function _getPrice(address token) internal returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token contract to find the ETH price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Price of the token in ETH|


### decodeSqrtPriceX96

Decodes the `SqrtPriceX96` value.


```solidity
function decodeSqrtPriceX96(address underlying, uint underlyingDecimalsScaler, uint sqrtPriceX96) private pure returns (uint price);
```

### _getPrices

This means that this function essentially acts as an intermediary function that just
subsequently calls `_getPrice` for each token passed. Not really gas efficient, but
unfortunately the best we can do with what we have.


```solidity
function _getPrices(address[] memory tokens) internal returns (uint[] memory);
```

### revertBytes

Gas efficient revert.


```solidity
function revertBytes(bytes memory errMsg) internal pure;
```

