// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract ERC721Mock is ERC721 {
    constructor() ERC721('Mock', 'MOCK') {}

    function mint(address to, uint tokenId) public {
        _mint(to, tokenId);
    }

    function burn(uint tokenId) public {
        _burn(tokenId);
    }
}