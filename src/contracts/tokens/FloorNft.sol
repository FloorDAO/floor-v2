// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import {ERC721, ERC721Lockable} from '@floor/tokens/extensions/ERC721Lockable.sol';

contract FloorNft is ERC721Lockable {
    /// Maintain an index of our current supply
    uint private supply;

    /// The URI of your IPFS/hosting server for the metadata folder
    string internal uri;

    /// Price of one NFT
    uint public constant cost = 0.05 ether;

    /// The maximum supply of your collection
    uint public maxSupply;

    /// The maximum mint amount allowed per transaction
    uint public maxMintAmountPerTx;

    /// The paused state for minting
    bool public paused = true;

    /// The Merkle Root used for whitelist minting
    bytes32 internal merkleRoot;

    /// Mapping of address to bool that determins wether the address already
    /// claimed the whitelist mint.
    mapping(address => bool) public whitelistClaimed;

    /**
     * Constructor function that sets name and symbol of the collection, cost,
     * max supply and the maximum amount a user can mint per transaction.
     *
     * @param _name Name of the ERC721 token
     * @param _symbol Symbol of the ERC721 token
     * @param _maxSupply The maximum number of tokens mintable
     * @param _maxMintAmountPerTx The maximum number of tokens mintable per transaction
     */
    constructor(string memory _name, string memory _symbol, uint _maxSupply, uint _maxMintAmountPerTx) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    /**
     * Returns the current supply of the collection.
     */
    function totalSupply() public view returns (uint) {
        return supply;
    }

    /**
     * Mint function to allow for public sale when not paused.
     *
     * @param _mintAmount The number of tokens to mint
     */
    function mint(uint _mintAmount) public payable mintCompliance(_mintAmount) {
        require(!paused, 'The contract is paused');
        require(msg.value >= cost * _mintAmount, 'Insufficient funds');

        _mintLoop(msg.sender, _mintAmount);
    }

    /**
     * The whitelist mint function to allow addresses on the merkle root to claim without
     * requiring a payment.
     */
    function whitelistMint(bytes32[] calldata _merkleProof) public payable mintCompliance(1) {
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

    /**
     * Returns the Token URI with Metadata for specified token ID.
     *
     * @param _tokenId The token ID to get the metadata URI for
     *
     * @return The metadata URI for the token ID
     */
    function tokenURI(uint _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');
        return bytes(uri).length > 0 ? string(abi.encodePacked(uri, Strings.toString(_tokenId), '.json')) : '';
    }

    /**
     * Set the maximum mint amount per transaction
     *
     * @param _maxMintAmountPerTx The new maximum tx mint amount
     */
    function setMaxMintAmountPerTx(uint _maxMintAmountPerTx) public onlyOwner {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    /**
     * Set the URI of your IPFS/hosting server for the metadata folder.
     *
     * @dev Used in the format: "ipfs://your_uri/".
     *
     * @param _uri New metadata base URI
     */
    function setUri(string memory _uri) public onlyOwner {
        uri = _uri;
    }

    /**
     * Change paused state for main minting. When enabled will allow public minting
     * to take place.
     */
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    /**
     * Set the Merkle Root for whitelist verification.
     *
     * @param _newMerkleRoot The new merkle root to assign to whitelist
     */
    function setMerkleRoot(bytes32 _newMerkleRoot) public onlyOwner {
        merkleRoot = _newMerkleRoot;
    }

    /**
     * Allows our max supply to be updated.
     */
    function setMaxSupply(uint _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    /**
     * Allows ETH to be withdrawn from the contract after the minting.
     *
     * @dev This should be sent to a {RevenueStakingStrategy} after being withdrawn
     * to promote yield generation.
     */
    function withdraw() public onlyOwner {
        (bool os,) = payable(owner()).call{value: address(this).balance}('');
        require(os);
    }

    /**
     * Helper function to process looped minting from different external functions.
     *
     * @param _receiver Recipient of the NFT
     * @param _mintAmount Number of tokens to mint to the receiver
     */
    function _mintLoop(address _receiver, uint _mintAmount) internal {
        for (uint i; i < _mintAmount;) {
            _safeMint(_receiver, supply + i);
            unchecked {
                i++;
            }
        }

        supply += _mintAmount;
    }

    /**
     * The base of the metadata URI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    /**
     * Modifier that ensures the maximum supply and the maximum amount to mint per
     * transaction.
     *
     * @param _mintAmount The amount of tokens trying to be minted
     */
    modifier mintCompliance(uint _mintAmount) {
        require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount');
        require(supply + _mintAmount <= maxSupply, 'Max supply exceeded');
        _;
    }

    /**
     * Allows the contract to receive payment for NFT sale.
     */
    receive() external payable {}
}
