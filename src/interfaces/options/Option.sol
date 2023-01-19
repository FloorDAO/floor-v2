// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";

/**
 * Non-fungible token representative of a user's option.
 *
 * Allows the optionto be transferred and authorized, as well as allowing for the generation
 * of a dynamic SVG representation of the option position. This will factor in the various
 * metadata attributes of the ERC721 to render a dynamic image.
 */
interface IOption is IERC721, IERC721Enumerable {
    /**
     * The amount of the asset token allocated to the user's option.
     *
     * @param tokenId The ID of the token that is being referrenced
     */
    function allocation(uint256 tokenId) external view returns (uint256);

    /**
     * The contract address of the token allocated in the option.
     *
     * @param tokenId The ID of the token that is being referrenced
     */
    function asset(uint256 tokenId) external view returns (uint256);

    /**
     * The amount of discount awarded to the user on the asset transaction.
     *
     * @param tokenId The ID of the token that is being referrenced
     */
    function discount(uint256 tokenId) external view returns (uint256);

    /**
     * The timestamp of which the option will expire.
     *
     * @param tokenId The ID of the token that is being referrenced
     */
    function expires(uint256 tokenId) external view returns (uint256);

    /**
     * Outputs a dynamically generated SVG image, representative of the Option NFT in it's
     * current state.
     *
     * When developing this logic, we should look at the libraries that UniSwap have published
     * from their recent V3 NFT work that simplify onchain SVG generation.
     *
     * @param tokenId The ID of the token that is being referrenced
     */
    function generateSVG(uint256 tokenId) external view returns (string memory);

    /**
     * Allows our {OptionExchange} to mint a token when the user claims it. This will write our
     * configuration parameters to an immutable state and allow our NFT SVG to be rendered.
     *
     * @param poolId The {OptionExchange} `OptionPool` index ID
     * @param allocation The amount of the asset token allocated to the user's option
     * @param asset The contract address of the token allocated in the option
     * @param discount The amount of discount awarded to the user on the asset transaction
     * @param expires The timestamp of which the option will expire
     */
    function mint(uint256 poolId, uint256 allocation, address asset, uint256 discount, uint256 expires) external;

    /**
     * Burns a token ID, which deletes it from the NFT contract. The token must have no remaining
     * allocation remaining in the option.
     *
     * @param tokenId The ID of the token that is being burned
     */
    function burn(uint256 tokenId) external;
}
