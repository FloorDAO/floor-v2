// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

import '../../interfaces/options/Option.sol';


contract Option is ERC721, ERC721Enumerable, ERC721Burnable, IOption {
    using Counters for Counters.Counter;

    // We cannot just use balanceOf to create the new tokenId because tokens
    // can be burned (destroyed), so we need a separate counter.
    Counters.Counter private _tokenIdTracker;

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
    mapping (uint => bytes32) private dna;

    /**
     * ERC721Permit is used to allow for gasless interaction.
     */
    constructor () ERC721Permit('FloorOption', 'FOPT') {}

    /**
     * Gets the allocation granted to the Option.
     */
    function allocation(uint256 tokenId) public view returns (uint) {
        return sliceUint(bytes8(dna[tokenId]));
    }

    /**
     * Gets the reward amount granted to the Option.
     */
    function rewardAmount(uint256 tokenId) public view returns (uint) {
        return sliceUint(bytes8(dna[tokenId]) >> 8);
    }

    /**
     * Gets the rarity of the Option, calculated at point of mint.
     */
    function rairty(uint256 tokenId) public view returns (uint) {
        return sliceUint(bytes4(dna[tokenId]) >> 16);
    }

    /**
     * Gets the pool ID that the Option is attributed to.
     */
    function poolId(uint256 tokenId) public view returns (uint) {
        return sliceUint(bytes8(dna[tokenId]) >> 20);
    }

    /**
     * Gets the expiry unix timestamp of the Option. This should not be
     * able to be actioned after the timestamp has passed.
     */
    function expiresAt() public view returns (uint) {
        return sliceUint(bytes64(dna[tokenId]) >> 28);
    }

    /**
     * Takes a bytes input and converts it to an integer
     */
    function sliceUint(bytes bs, uint start) internal pure returns (uint x) {
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
     * Returns a Base64 encoded JSON structure that outlines the contents of our token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId));

        return
            constructTokenURI(
                tokenId,
                ConstructTokenURIParams({
                    tokenId: tokenId,
                    allocation: allocation(tokenId),
                    token: 'PUNK',
                    rewardAmount: rewardAmount(tokenId),
                    rarity: rarity(tokenId),
                    poolId: poolId(tokenId),
                    expiresAt: expires(tokenId)
                })
            );
    }

    /**
     * Save bytecode by removing implementation of unused method.
     */
    function baseURI() public pure override returns (string memory) {}

    /**
     * Allows the user to burn their token. Validation is handled within the
     * parent `_burn` logic.
     */
    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function constructTokenURI(uint256 tokenId, ConstructTokenURIParams memory params) public pure returns (string memory) {
        string memory name = generateName(params);
        string memory descriptionPartOne = generateDescription(params);
        string memory image = Base64.encode(tokenId, bytes(NFTSVG.generateSVG(tokenId)));

        return
            string(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name,
                                '", "description":"',
                                description,
                                '", "image": "',
                                'data:image/svg+xml;base64,',
                                image,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateDescription(ConstructTokenURIParams memory params) private pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    'This NFT represents a reward option in a Floor.xyz for the ',
                    params.token,
                    ' pool. The owner of this NFT can redeem against the reward.'
                )
            );
    }

    function generateName(ConstructTokenURIParams memory params) private pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    'Floor Option',
                    ' - ',
                    params.token,
                    ' - ',
                    params.allocation.toString(),
                    '% Allocation',
                    ' - ',
                    params.rewardAmount.toString(),
                    '% Discount'
                )
            );
    }

    function tokenToColorHex(uint256 tokenId, uint256 offset) internal pure returns (string memory str) {
        return string((tokenId >> offset).toHexStringNoPrefix(3));
    }

    function tokenRarityToColourHex(uint4 rarity) internal pure returns (string memory str) {
        if (rarity == 1) {
            return 'FFD700';
        }

        if (rarity == 2) {
            return 'FFD700';
        }

        if (rarity == 3) {
            return 'FFD700';
        }

        return '14F5DA';
    }

    function generateSVG(uint256 tokenId) internal pure returns (string memory svg) {
        return string(
            abi.encodePacked(
                '<svg width="56" height="56" viewBox="0 0 56 56" fill="none" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="56" height="56" rx="10.5" fill="#0A0A0A"/>',
                    '<rect width="56" height="56" rx="10.5" fill="url(#paint0_linear_845_901)" fill-opacity="0.2"/>',
                    '<path d="M13.125 31.875C12.6418 31.875 12.25 31.4832 12.25 31V24.875C12.25 24.3918 12.6418 24 13.125 24H42.875C43.3582 24 43.75 24.3918 43.75 24.875V31C43.75 31.4832 43.3582 31.875 42.875 31.875H13.125Z" fill="#',
                    tokenRarityToColourHex(rarity(tokenId)),
                    '"/>',

                    // Token
                    '<g style="transform:translate(29px, 384px)">',
                    '<rect width="100px" height="26px" rx="8px" ry="8px" fill="rgba(0,0,0,0.6)" />',
                    '<text x="12px" y="17px" font-family="\'Courier New\', monospace" font-size="12px" fill="white"><tspan fill="rgba(255,255,255,0.6)">TOKEN: </tspan>',
                    params.token,
                    '</text></g>',

                    // Allocation
                    '<g style="transform:translate(29px, 384px)">',
                    '<rect width="50px" height="26px" rx="8px" ry="8px" fill="rgba(0,0,0,0.6)" />',
                    '<text x="12px" y="17px" font-family="\'Courier New\', monospace" font-size="12px" fill="white"><tspan fill="rgba(255,255,255,0.6)">TOKEN: </tspan>',
                    params.allocation,
                    '%</text></g>',

                    // Reward
                    '<g style="transform:translate(29px, 384px)">',
                    '<rect width="120px" height="26px" rx="8px" ry="8px" fill="rgba(0,0,0,0.6)" />',
                    '<text x="12px" y="17px" font-family="\'Courier New\', monospace" font-size="12px" fill="white"><tspan fill="rgba(255,255,255,0.6)">TOKEN: </tspan>',
                    params.rewardAmount,
                    '% OFF</text></g>',

                    '<defs>',
                        '<linearGradient id="paint0_linear_845_901" x1="0" y1="0" x2="56" y2="56" gradientUnits="userSpaceOnUse">',
                            '<stop stop-color="#',
                            tokenToColorHex(tokenId, 420),
                            '" stop-opacity="0.24"/>',
                            '<stop offset="1" stop-color="#0A0A0A"/>',
                        '</linearGradient>',
                    '</defs>',
                '</svg>'
            )
        );
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

}
