// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INewCollectionWarOptions {
    /**
     * Stores information about a user's option.
     */
    struct Option {
        uint tokenId; // 256 / 256
        address user; // 416 / 512
        uint96 amount; // 512 / 512
    }

    /**
     * Stores information about the NFT that has been staked. This allows either
     * the DAO to exercise the NFT, or for the initial staker to reclaim it.
     */
    struct StakedCollectionERC721 {
        address staker; // 160 / 256
        uint56 exercisePercent; // 216 / 256
    }

    struct StakedCollectionERC1155 {
        address staker; // 160 / 256
        uint56 exercisePercent; // 216 / 256
        uint40 amount; // 256 / 256
    }

    /// Sent when Collection Addition War NFTs are exercised
    event CollectionExercised(uint warIndex, address collection, uint value);

    function createOption(uint war, address collection, uint[] calldata tokenIds, uint40[] calldata amounts, uint56[] calldata exercisePercents) external;

    function reclaimOptions(uint war, address collection, uint56[] calldata exercisePercents, uint[][] calldata indexes) external;

    function exerciseOptions(uint war, uint amount) external payable;

    function nftVotingPower(uint war, address collection, uint spotPrice, uint exercisePercent) external view returns (uint);

}
