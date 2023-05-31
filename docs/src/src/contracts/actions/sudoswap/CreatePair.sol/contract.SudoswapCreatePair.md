# SudoswapCreatePair
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fd4de86a192de96d73fe2e56a84ec542b57b1c69/src/contracts/actions/sudoswap/CreatePair.sol)

**Inherits:**
[Action](/src/contracts/actions/Action.sol/contract.Action.md)

New pairs for the sudoswap AMM are created with the LSSVMPairFactory. LPs will call
either createPairETH or createPairERC20 depending on their token type (i.e. if they
wish to utilize ETH or an ERC20). This will deploy a new LSSVMPair contract.
Each pair has one owner (initially set to be the caller), and multiple pools for the
same token and NFT pair can exist, even for the same owner. This is due to each pair
having its own potentially different spot price and bonding curve.

*https://docs.sudoswap.xyz/reference/pair-creation/*


## State Variables
### pairFactory
Store our pair factory


```solidity
LSSVMPairFactory public immutable pairFactory;
```


## Functions
### constructor

We assign any variable contract addresses in our constructor, allowing us
to have multiple deployed actions if any parameters change.


```solidity
constructor(address payable _pairFactory);
```

### execute

Creates a new Sudoswap pairing.


```solidity
function execute(bytes calldata _request) public payable override whenNotPaused returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_request`|`bytes`|Packed bytes that will map to our `ActionRequest` struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|uint Integer representation of the created pair address|


## Structs
### ActionRequest

```solidity
struct ActionRequest {
    address token;
    address nft;
    address bondingCurve;
    LSSVMPair.PoolType poolType;
    uint128 delta;
    uint96 fee;
    uint128 spotPrice;
    uint initialTokenBalance;
    uint[] initialNftIds;
}
```

