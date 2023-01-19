// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract ERC1155Mock is ERC1155 {
    bytes32 public constant URI_SETTER_ROLE = keccak256('URI_SETTER_ROLE');
    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');

    constructor() ERC1155('') {}

    function setURI(string memory newuri) public {
        _setURI(newuri);
    }

    function mint(address account, uint id, uint amount, bytes memory data) public {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint[] memory ids, uint[] memory amounts, bytes memory data) public {
        _mintBatch(to, ids, amounts, data);
    }
}
