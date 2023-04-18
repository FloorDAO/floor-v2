// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Counters} from '@openzeppelin/contracts/utils/Counters.sol';
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import {ERC721, ERC721Lockable} from '@floor/tokens/extensions/ERC721Lockable.sol';


contract FloorNft is ERC721Lockable {
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    // The URI of your IPFS/hosting server for the metadata folder.
    // Used in the format: "ipfs://your_uri/".
    string internal uri;

    // Price of one NFT
    uint public constant cost = 0.05 ether;

    // The maximum supply of your collection
    uint public maxSupply;

    // The maximum mint amount allowed per transaction
    uint public maxMintAmountPerTx;

    // The paused state for minting
    bool public paused = true;

    // Presale state
    bool public presale = true;

    // The Merkle Root
    bytes32 internal merkleRoot;

    // Mapping of address to bool that determins wether the address already claimed the whitelist mint
    mapping(address => bool) public whitelistClaimed;

    // Constructor function that sets name and symbol
    // of the collection, cost, max supply and the maximum
    // amount a user can mint per transaction
    constructor(
        string memory _name,
        string memory _symbol,
        uint _maxSupply,
        uint _maxMintAmountPerTx
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    /**
     * Allows our max supply to be updated.
     */
    function setMaxSupply(uint _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    /**
     * Modifier that ensures the maximum supply and the maximum amount to mint per
     * transaction.
     */
    modifier mintCompliance(uint _mintAmount) {
        require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount');
        require(supply.current() + _mintAmount <= maxSupply, 'Max supply exceeded');

        _;
    }

    // Returns the current supply of the collection
    function totalSupply() public view returns (uint) {
        return supply.current();
    }

    // Mint function
    function mint(uint _mintAmount) public payable mintCompliance(_mintAmount) {
        require(!presale, 'Sale is not active');
        require(!paused, 'The contract is paused');
        require(msg.value >= cost * _mintAmount, 'Insufficient funds');

        _mintLoop(msg.sender, _mintAmount);
    }

    // The whitelist mint function
    function whitelistMint(bytes32[] calldata _merkleProof) public payable mintCompliance(1) {
        // Ensure that the contracty is not paused
        require(!paused, 'The contract is paused');

        // Ensure that the user has not already claimed their whitelist spot
        require(!whitelistClaimed[msg.sender], 'Address has already claimed');

        // Generate the leaf based on the sender
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        // Validate that our user was included in the whitelist
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), 'Invalid proof');

        // Mark our user as having claimed the whitelist
        whitelistClaimed[msg.sender] = true;

        // Mint to our user
        _mintLoop(msg.sender, 1);
    }

    // Returns the Token URI with Metadata for specified Token Id
    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        Strings.toString(_tokenId),
                        '.json'
                    )
                )
                : "";
    }

    // Set the maximum mint amount per transaction
    function setMaxMintAmountPerTx(uint _maxMintAmountPerTx) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    // Set the URI of your IPFS/hosting server for the metadata folder.
    // Used in the format: "ipfs://your_uri/".
    function setUri(string memory _uri) public onlyOwner {
        uri = _uri;
    }

    // Change paused state for main minting
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    // Change paused state of minting for presale
    function setPresale(bool _bool) public onlyOwner {
        presale = _bool;
    }

    // Set the Merkle Root for whitelist verification
    function setMerkleRoot(bytes32 _newMerkleRoot) public onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    // Withdraw ETH after sale
    function withdraw() public onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // Helper function
    function _mintLoop(address _receiver, uint _mintAmount) internal {
        for (uint i = 0; i < _mintAmount;) {
            _safeMint(_receiver, supply.current());
            supply.increment();

            unchecked { i++; }
        }
    }

    // ..
    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    // ..
    receive() external payable {}
}
