// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev The Treasury will hold all assets.
 */
interface ITreasury {
    /// @dev When native network token is withdrawn from the Treasury
    event Deposit(uint amount);

    /// @dev When an ERC20 is depositted into the vault
    event DepositERC20(address token, uint amount);

    /// @dev When an ERC721 is depositted into the vault
    event DepositERC721(address token, uint tokenId);

    /// @dev When an ERC1155 is depositted into the vault
    event DepositERC1155(address token, uint tokenId, uint amount);

    /// @dev When native network token is withdrawn from the Treasury
    event Withdraw(uint amount, address recipient);

    /// @dev When an ERC20 token is withdrawn from the Treasury
    event WithdrawERC20(address token, uint amount, address recipient);

    /// @dev When an ERC721 token is withdrawn from the Treasury
    event WithdrawERC721(address token, uint tokenId, address recipient);

    /// @dev When an ERC1155 is withdrawn from the vault
    event WithdrawERC1155(address token, uint tokenId, uint amount, address recipient);

    /// @dev When multiplier pool has been updated
    event MultiplierPoolUpdated(uint percent);

    /// @dev When FLOOR is minted
    event FloorMinted(uint amount);

    /**
     * Allow FLOOR token to be minted. This should be called from the deposit method
     * internally, but a public method will allow a {TreasuryManager} to bypass this
     * and create additional FLOOR tokens if needed.
     *
     * @dev We only want to do this on creation and for inflation. Have a think on how
     * we can implement this!
     */
    function mint(uint amount) external;

    /**
     * Allows an ERC20 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     */
    function depositERC20(address token, uint amount) external;

    /**
     * Allows an ERC721 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     */
    function depositERC721(address token, uint tokenId) external;

    /**
     * Allows an ERC1155 token(s) to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     */
    function depositERC1155(address token, uint tokenId, uint amount) external;

    /**
     * Allows an approved user to withdraw native token.
     */
    function withdraw(address recipient, uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC20 token from the vault.
     */
    function withdrawERC20(address recipient, address token, uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC721 token from the vault.
     */
    function withdrawERC721(address recipient, address token, uint tokenId) external;

    /**
     * Allows an approved user to withdraw an ERC1155 token(s) from the vault.
     */
    function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external;

    /**
     * Sets the percentage of treasury rewards yield to be retained by the treasury, with
     * the remaining percetange distributed to non-treasury vault stakers based on the GWV.
     */
    function setRetainedTreasuryYieldPercentage(uint percent) external;

    /**
     * ..
     */
    function sweepEpoch(uint epochIndex, address sweeper) external;

    /**
     * ..
     */
    function resweepEpoch(uint epochIndex, address sweeper) external;

    /**
     * ..
     */
    function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts) external;

    /**
     * ..
     */
    function retainedTreasuryYieldPercentage() external returns (uint);

    /**
     * ..
     */
    function minSweepAmount() external returns (uint);
}
