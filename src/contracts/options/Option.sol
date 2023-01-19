// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

import '../../interfaces/options/Option.sol';

contract Option is ERC721URIStorage {
    using Counters for Counters.Counter;

    // We cannot just use balanceOf to create the new tokenId because tokens
    // can be burned (destroyed), so we need a separate counter.
    Counters.Counter private _tokenIdTracker;

    constructor() ERC721('FloorOption', 'FOPT') {}

    /**
     * The DNA of our Option defines the struct of our Option, but without the
     * space allocation requirement. We do this through using byte manipulation.
     *
     * In this we reference the following:
     *
     * [allocation][reward amount][rarity][pool id]
     *      8             8           4       8
     *
     * This DNA will not be unique as the ID value of this DNA will not be unique
     * as we don't factor in the ID of the token. This ID will be a uint256 and the
     * purpose of using bytes is to keep it within a fixed, predictable amount.
     *
     * /// @dev 798 gas cost :)
     * function concatBytes(
     *  bytes2 _c,
     *  bytes2 _d
     * ) public pure returns (bytes4) {
     *  return (_c << 4) | _d;
     * }
     */
    mapping(uint => bytes32) private dna;

    /**
     * Gets the allocation granted to the Option.
     */
    function allocation(uint tokenId) public view returns (uint) {
        return sliceUint(dna[tokenId], 0);
    }

    /**
     * Gets the reward amount granted to the Option.
     */
    function rewardAmount(uint tokenId) public view returns (uint) {
        return sliceUint(dna[tokenId], 8);
    }

    /**
     * Gets the rarity of the Option, calculated at point of mint.
     */
    function rarity(uint tokenId) public view returns (uint) {
        return sliceUint(dna[tokenId], 16);
    }

    /**
     * Gets the pool ID that the Option is attributed to.
     */
    function poolId(uint tokenId) public view returns (uint) {
        return sliceUint(dna[tokenId], 20);
    }

    /**
     * Takes a bytes input and converts it to an integer
     */
    function sliceUint(bytes32 bs, uint start) internal pure returns (uint x) {
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
    }

    /**
     * Mints our token with a set DNA.
     */
    function mint(address _to, bytes32 _dna) public virtual {
        // require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        _mint(_to, _tokenIdTracker.current());
        dna[_tokenIdTracker.current()] = _dna;
        _tokenIdTracker.increment();
    }

    /**
     * Save bytecode by removing implementation of unused method.
     */
    function baseURI() public pure returns (string memory) {}

    function _beforeTokenTransfer(address from, address to, uint firstTokenId, uint batchSize)
        internal
        virtual
        override
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
