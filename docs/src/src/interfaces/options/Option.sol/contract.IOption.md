# IOption
[Git Source](https://github.com/FloorDAO/floor-v2/blob/537a38ba21fa97b6f7763cc3c1b0ee2a21e56857/src/interfaces/options/Option.sol)

**Inherits:**
IERC721, IERC721Enumerable

Non-fungible token representative of a user's option.
Allows the optionto be transferred and authorized, as well as allowing for the generation
of a dynamic SVG representation of the option position. This will factor in the various
metadata attributes of the ERC721 to render a dynamic image.


## Functions
### allocation

The amount of the asset token allocated to the user's option.


```solidity
function allocation(uint tokenId) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that is being referrenced|


### asset

The contract address of the token allocated in the option.


```solidity
function asset(uint tokenId) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that is being referrenced|


### discount

The amount of discount awarded to the user on the asset transaction.


```solidity
function discount(uint tokenId) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that is being referrenced|


### expires

The timestamp of which the option will expire.


```solidity
function expires(uint tokenId) external view returns (uint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that is being referrenced|


### generateSVG

Outputs a dynamically generated SVG image, representative of the Option NFT in it's
current state.
When developing this logic, we should look at the libraries that UniSwap have published
from their recent V3 NFT work that simplify onchain SVG generation.


```solidity
function generateSVG(uint tokenId) external view returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that is being referrenced|


### mint

Allows our {OptionExchange} to mint a token when the user claims it. This will write our
configuration parameters to an immutable state and allow our NFT SVG to be rendered.


```solidity
function mint(uint poolId, uint allocation, address asset, uint discount, uint expires) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolId`|`uint256`|The {OptionExchange} `OptionPool` index ID|
|`allocation`|`uint256`|The amount of the asset token allocated to the user's option|
|`asset`|`address`|The contract address of the token allocated in the option|
|`discount`|`uint256`|The amount of discount awarded to the user on the asset transaction|
|`expires`|`uint256`|The timestamp of which the option will expire|


### burn

Burns a token ID, which deletes it from the NFT contract. The token must have no remaining
allocation remaining in the option.


```solidity
function burn(uint tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token that is being burned|


