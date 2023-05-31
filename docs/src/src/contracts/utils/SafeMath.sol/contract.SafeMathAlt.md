# SafeMathAlt
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/utils/SafeMath.sol)

*Wrappers over Solidity's arithmetic operations.
NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
now has built in overflow checking.*


## Functions
### tryAdd

*Returns the addition of two unsigned integers, with an overflow flag.
_Available since v3.4._*


```solidity
function tryAdd(uint a, uint b) internal pure returns (bool, uint);
```

### trySub

*Returns the substraction of two unsigned integers, with an overflow flag.
_Available since v3.4._*


```solidity
function trySub(uint a, uint b) internal pure returns (bool, uint);
```

### tryMul

*Returns the multiplication of two unsigned integers, with an overflow flag.
_Available since v3.4._*


```solidity
function tryMul(uint a, uint b) internal pure returns (bool, uint);
```

### tryDiv

*Returns the division of two unsigned integers, with a division by zero flag.
_Available since v3.4._*


```solidity
function tryDiv(uint a, uint b) internal pure returns (bool, uint);
```

### tryMod

*Returns the remainder of dividing two unsigned integers, with a division by zero flag.
_Available since v3.4._*


```solidity
function tryMod(uint a, uint b) internal pure returns (bool, uint);
```

### add

*Returns the addition of two unsigned integers, reverting on
overflow.
Counterpart to Solidity's `+` operator.
Requirements:
- Addition cannot overflow.*


```solidity
function add(uint a, uint b) internal pure returns (uint);
```

### sub

*Returns the subtraction of two unsigned integers, reverting on
overflow (when the result is negative).
Counterpart to Solidity's `-` operator.
Requirements:
- Subtraction cannot overflow.*


```solidity
function sub(uint a, uint b) internal pure returns (uint);
```

### mul

*Returns the multiplication of two unsigned integers, reverting on
overflow.
Counterpart to Solidity's `*` operator.
Requirements:
- Multiplication cannot overflow.*


```solidity
function mul(uint a, uint b) internal pure returns (uint);
```

### div

*Returns the integer division of two unsigned integers, reverting on
division by zero. The result is rounded towards zero.
Counterpart to Solidity's `/` operator.
Requirements:
- The divisor cannot be zero.*


```solidity
function div(uint a, uint b) internal pure returns (uint);
```

### mod

*Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
reverting when dividing by zero.
Counterpart to Solidity's `%` operator. This function uses a `revert`
opcode (which leaves remaining gas untouched) while Solidity uses an
invalid opcode to revert (consuming all remaining gas).
Requirements:
- The divisor cannot be zero.*


```solidity
function mod(uint a, uint b) internal pure returns (uint);
```

### sub

*Returns the subtraction of two unsigned integers, reverting with custom message on
overflow (when the result is negative).
CAUTION: This function is deprecated because it requires allocating memory for the error
message unnecessarily. For custom revert reasons use {trySub}.
Counterpart to Solidity's `-` operator.
Requirements:
- Subtraction cannot overflow.*


```solidity
function sub(uint a, uint b, string memory errorMessage) internal pure returns (uint);
```

### div

*Returns the integer division of two unsigned integers, reverting with custom message on
division by zero. The result is rounded towards zero.
Counterpart to Solidity's `/` operator. Note: this function uses a
`revert` opcode (which leaves remaining gas untouched) while Solidity
uses an invalid opcode to revert (consuming all remaining gas).
Requirements:
- The divisor cannot be zero.*


```solidity
function div(uint a, uint b, string memory errorMessage) internal pure returns (uint);
```

### mod

*Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
reverting with custom message when dividing by zero.
CAUTION: This function is deprecated because it requires allocating memory for the error
message unnecessarily. For custom revert reasons use {tryMod}.
Counterpart to Solidity's `%` operator. This function uses a `revert`
opcode (which leaves remaining gas untouched) while Solidity uses an
invalid opcode to revert (consuming all remaining gas).
Requirements:
- The divisor cannot be zero.*


```solidity
function mod(uint a, uint b, string memory errorMessage) internal pure returns (uint);
```

### toInt256

*Converts an unsigned uint256 into a signed int256.
Requirements:
- input must be less than or equal to maxInt256.*


```solidity
function toInt256(uint value) internal pure returns (int);
```

