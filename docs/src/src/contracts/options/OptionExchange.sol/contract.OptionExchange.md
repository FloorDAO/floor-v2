# OptionExchange
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/contracts/options/OptionExchange.sol)

**Inherits:**
ConfirmedOwner, [IOptionExchange](/src/interfaces/options/OptionExchange.sol/contract.IOptionExchange.md), VRFV2WrapperConsumerBase

The {OptionExchange} will allow FLOOR to be burnt to redeem treasury assets.
This is important to allow us to balance token value against treasury backed
assets that are accumulated.
Our {OptionExchange} will allow a {TreasuryManager} to transfer an ERC20 from
the {Treasury} and create an `OptionPool` with a defined available amount,
maximum discount and expiry timestamp.
With a pool, we can then hit an API via ChainLink to generate a range of random
`OptionAllocation`s that will provide the lucky recipient with access to burn
their FLOOR tokens for allocated treasury assets at a discount. This discount
will be randomly assigned and user's will receive a maximum of one option per
pool allocation.
We hit an external API as Solidity randomness is not random.
Further information about this generation is outlined in the `generateAllocations`
function documentation.


## State Variables
### _options
Maintain a list of options that we will append and delete
from during the generation process.


```solidity
bytes32[] _options;
```


### weighting
Our Option Distribution Weighting ladder is stored as an external
contract to allow ongoing optimisation and manipulation of the
desired algorithm. All it requires is for us to be able to send
a seeded `get` call to return a value.


```solidity
OptionDistributionWeightingCalculator public weighting;
```


### pools
..


```solidity
OptionPool[] internal pools;
```


### s_requests
..


```solidity
mapping(uint => RequestStatus) public s_requests;
```


### optionPoolMerkleRoots
Maps the poolId to a merkle root


```solidity
mapping(uint => bytes32) public optionPoolMerkleRoots;
```


### optionPoolMerkleRootClaims
We keep a track of the claims mapping the merkle DNA to true/false


```solidity
mapping(bytes32 => bool) public optionPoolMerkleRootClaims;
```


### treasury
..


```solidity
address public immutable treasury;
```


### linkAddress

```solidity
address public immutable linkAddress;
```


### callbackGasLimit

```solidity
uint32 callbackGasLimit = 100000;
```


### requestConfirmations

```solidity
uint16 requestConfirmations = 16;
```


### numWords

```solidity
uint32 numWords = 2;
```


## Functions
### constructor

...


```solidity
constructor(address _treasury, address _linkAddress, address _wrapperAddress)
    ConfirmedOwner(msg.sender)
    VRFV2WrapperConsumerBase(_linkAddress, _wrapperAddress);
```

### setOptionDistributionWeightingCalculator

Allows an approved caller to update the weighting calculator contract.


```solidity
function setOptionDistributionWeightingCalculator(address _weighting) external;
```

### getOptionPool

Provides the `OptionPool` struct data. We sense check that the pool exists
and revert if it does not.


```solidity
function getOptionPool(uint poolId) external view returns (OptionPool memory);
```

### createPool

Allows our {TreasuryManager} to create an `OptionPool` from tokens that have been
passed in from the `deposit` function. We need to ensure that we have
sufficient token amounts in the contract.
This would mean that user's would not be able to action their {Option}, which is
a bad thing.
Should emit the {OptionPoolCreated} event.


```solidity
function createPool(address token, uint amount, uint16 maxDiscount, uint64 expires) external returns (uint poolId);
```

### generateAllocations

Starts the process of our allocation generation; sending a request to a specified
ChainLink node and returning the information required to generate a range of
{OptionAllocation} structs.
This generation will need to function via a hosted API that will determine the
share and discount attributes for an option. From these two attributes we will
also define a rarity ranking based on the liklihood of the result.
The algorithm for the attributions can be updated as needed, but in it's current
iteration they are both derived from a right sided bell curve. This ensures no
negative values, but provides the majority of the distribution to be allocated
across smaller numbers.
https://www.investopedia.com/terms/b/bell-curve.asp
The allocation of the amount should not allow for a zero value, but the discount
can be.
Chainlink will return a bytes32 request ID that we can track internally over the
process so that when it is subsequently fulfilled we can map our allocations to
the correct `OptionPool`.
When this call is made, if we have a low balance of $LINK token in our contract
then we will need to fire an {LinkBalanceLow} event to pick this up.


```solidity
function generateAllocations(uint poolId) external returns (uint requestId);
```

### fulfillRandomWords

Our Chainlink response will trigger this function. We will need to validate the
`requestId` is currently pending for the contract and then parse the `bytesData`
into a format through which we can create a range of `OptionAllocation`.
We will need to return packed bytes that we can iterate through, allowing for a
variable length of results to be sent. With bit manipulation we can aim to keep
the required amount of data passed to a minimum.
We should expect only our defined Oracle to call this method, so validation should
be made around this.


```solidity
function fulfillRandomWords(uint _requestId, uint[] memory _randomWords) internal virtual override;
```

### rarityScore

This wants to return a range from 0 - 100 to define rarity. A lower rarity
value will be rarer, whilst a higher value will be more common.


```solidity
function rarityScore(uint share, uint discount, uint maxDiscount) public pure returns (uint8);
```

### mintOptionAllocation

Allows the specified recipient to mint their `OptionAllocation`. This will
need to ensure that the relevant `OptionalPool` has not expired and the expected
sense checks, such as that it exists, has not already been allocated, etc.
As a recipient address can only be programatically allocated a singular option
per-pool during the generation process, we can determine the option by just
providing the `poolId` and then checking that the `msg.sender` matches the
`OptionAllocation`.`recipient`
Once this has been minted we should delete the appropriate `OptionAllocation`
as this will prevent subsequent minting and also gives some gas refunds.
Once minted, an ERC721 will be transferred to the recipient that will be used
to allow the holder to partially or fully action the option.


```solidity
function mintOptionAllocation(bytes32 dna, uint index, bytes32[] calldata merkleProof) external;
```

### action

We should be able to action a holders {Option} to allow them to exchange their
FLOOR token for another token. This will take the allocation amount in their
{Option} token, as well as factoring in their discount, to determine the amount
of token they will receive in exchange.
As the user's allocation is based on the target token, rather than FLOOR, we want
to ensure that the user is left with as little dust as possible. This means the
amount of FLOOR (`tokenIn`) required may change during the transaction lifetime,
but the amount of `tokenOut` should always remain the same.
It's for this reason that we have an `approvedMovement` attribute. Similar to how
slippage would be handled, we allow the user to specify a range of FLOOR input
variance that they are willing to accept. The frontend UX will need to correlate
this against the user's balance as, for example, they may enter their full balance
and specify 1% movement, but they could not acommodate this.
The sender will need to have approved this contract to manage their FLOOR token
as we will transfer the required equivalent value of the token.
There will be a number of validation steps to our action flow here:
- Does the sender has permission to action the {Option}?
- Does the sender hold sufficient FLOOR?
- Does the {Option} have sufficient allocation for the floorIn requested?
- Does the floorIn / tokenOut make sense at current price within approvedMovement?
The final FLOOR requirement should follow this pseudo algorithm:
floor pre-discount  = tokens out * (token value / floor value)
floor required (fr) = f - ((f * discount) / 100)
We can then assert floor required against our approved movement:
(floorIn - (approvedMovement * (floorIn / 100))) < fr < (floorIn + (approvedMovement * (floorIn / 100)))
FLOOR received from this transaction will be sent to an address. Upon contract
creation this will be sent to a 0x0 NULL address to burn the token, but can be
updated via the `setFloorRecipient` function.
If there is no remaining amount in the `OptionPool`, then the `OptionPool` will
not be deleted for historical purposes, but would emit the {OptionPoolClosed} event.


```solidity
function action(uint tokenId, uint floorIn, uint tokenOut, uint approvedMovement) external;
```

### getRequiredFloorPrice

The amount of FLOOR required to mint the specified `amount` of the `token`.
This will call our {Treasury} to get the required price via the {PriceExecutor}.


```solidity
function getRequiredFloorPrice(address token, uint amount) external returns (uint);
```

### claimableOptionAllocations

Provides a list of all allocations that the user has available to be minted.


```solidity
function claimableOptionAllocations(address recipient) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|Address of the claimant|


### withdraw

After an `OptionPool` has expired, any remaining token amounts can be transferred
back to the {Treasury} using this function. We must first ensure that it has expired
before performing this transaction.
This will emit this {OptionPoolClosed} event.


```solidity
function withdraw(uint poolId) external;
```

### depositLink

Allows any sender to provide ChainLink token balance to the contract. This is
required for the generation of our user allocations.
This should emit the {LinkBalanceIncreased} event.


```solidity
function depositLink(uint amount) external;
```

### setFloorRecipient

By default, FLOOR received from an {Option} being actioned will be burnt by
sending it to a NULL address. If decisions change in the future then we want
to be able to update the recipient address.
Should emit {UpdatedFloorRecipient} event.


```solidity
function setFloorRecipient(address newRecipient) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRecipient`|`address`|The new address that will receive exchanged FLOOR tokens|


### _detectLowLinkBalance


```solidity
function _detectLowLinkBalance() internal;
```

### getRequestStatus


```solidity
function getRequestStatus(uint _requestId) external view returns (uint paid, bool fulfilled, uint[] memory randomWord);
```

