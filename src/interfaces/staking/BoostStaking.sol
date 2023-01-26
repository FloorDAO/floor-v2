// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBoostStaking {
    /// Emitted when an NFT is staked
    event Staked(uint tokenId);

    /// Emitted when an NFT is unstaked
    event Unstaked(uint tokenId);

    /**
     * Returns the address of the user that has staked the specified `tokenId`.
     */
    function tokenStaked(uint) external returns (address);

    /**
     * Gets the number tokens that a user has staked at each boost value.
     */
    function userTokens(address, uint8) external returns (uint16);

    /**
     * The boost value applied to the user.
     */
    function boosts(address) external returns (uint);

    /**
     * NFT contract address.
     */
    function nft() external returns (address);

    /**
     * Stakes an approved NFT into the contract and provides a boost based on the relevant
     * metadata on the NFT.
     *
     * @dev This can only be called when the contract is not paused.
     */
    function stake(uint _tokenId) external;

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     */
    function unstake(uint _tokenId) external;
}
