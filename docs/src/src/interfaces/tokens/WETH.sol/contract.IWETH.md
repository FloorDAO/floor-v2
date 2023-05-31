# IWETH
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/interfaces/tokens/WETH.sol)

**Inherits:**
IERC20


## Functions
### allowance


```solidity
function allowance(address, address) public view virtual returns (uint);
```

### balanceOf


```solidity
function balanceOf(address) public view virtual returns (uint);
```

### approve


```solidity
function approve(address, uint) public virtual returns (bool);
```

### transfer


```solidity
function transfer(address, uint) public virtual returns (bool);
```

### transferFrom


```solidity
function transferFrom(address, address, uint) public virtual returns (bool);
```

### deposit


```solidity
function deposit() public payable virtual;
```

### withdraw


```solidity
function withdraw(uint) public virtual;
```

