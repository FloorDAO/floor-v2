# TokenUtils
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/utils/TokenUtils.sol)


## State Variables
### WSTETH_ADDR

```solidity
address public constant WSTETH_ADDR = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
```


### STETH_ADDR

```solidity
address public constant STETH_ADDR = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
```


### WETH_ADDR

```solidity
address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


### ETH_ADDR

```solidity
address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
```


## Functions
### approveToken


```solidity
function approveToken(address _tokenAddr, address _to, uint _amount) internal;
```

### pullTokensIfNeeded


```solidity
function pullTokensIfNeeded(address _token, address _from, uint _amount) internal returns (uint);
```

### withdrawTokens


```solidity
function withdrawTokens(address _token, address _to, uint _amount) internal returns (uint);
```

### depositWeth


```solidity
function depositWeth(uint _amount) internal;
```

### withdrawWeth


```solidity
function withdrawWeth(uint _amount) internal;
```

### getBalance


```solidity
function getBalance(address _tokenAddr, address _acc) internal view returns (uint);
```

