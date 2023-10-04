// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract ERC721Mock is ERC721 {
    uint fees;

    constructor() ERC721('Mock', 'MOCK') {}

    function mint(address to, uint tokenId) public {
        _mint(to, tokenId);
    }

    function burn(uint tokenId) public {
        _burn(tokenId);
    }

    function setRoyaltyFees(uint percentage) public {
        fees = percentage;
    }

    /**
     * Called with the sale price to determine how much royalty is owed and to whom.
     *
     * @param _salePrice - the sale price of the NFT asset specified by _tokenId
     *
     * @return receiver - address of who should be sent the royalty payment
     * @return royaltyAmount - the royalty payment amount for _salePrice
     */
    function royaltyInfo(uint /* _tokenId */, uint _salePrice) external view returns (address receiver, uint royaltyAmount) {
        receiver = address(1);
        royaltyAmount = _salePrice * fees / 100_000;
    }
}
