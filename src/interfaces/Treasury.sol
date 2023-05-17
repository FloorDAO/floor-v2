// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


library TreasuryEnums {
    /// Different sweep types that can be specified.
    enum SweepType {
        COLLECTION_ADDITION,
        SWEEP
    }

    /// Different approval types that can be specified.
    enum ApprovalType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }
}


/**
 * @dev The Treasury will hold all assets.
 */
interface ITreasury {

    /// Stores data that allows the Treasury to action a sweep.
    struct Sweep {
        TreasuryEnums.SweepType sweepType;
        address[] collections;
        uint[] amounts;
        bool completed;
        string message;
    }

    /// The data structure format that will be mapped against to define a token
    /// approval request.
    struct ActionApproval {
        TreasuryEnums.ApprovalType _type; // Token type
        address assetContract; // Used by 20, 721 and 1155
        uint tokenId; // Used by 721 tokens
        uint amount; // Used by native and 20 tokens
    }

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

    /// @dev When FLOOR is minted
    event FloorMinted(uint amount);

    /// @dev When a {Treasury} action is processed
    event ActionProcessed(address action, bytes data);

    /// @dev When a sweep is registered against an epoch
    event SweepRegistered(uint epochIndex);

    /// @dev When an action is assigned to a sweep epoch
    event SweepAction(uint sweepEpoch);

    /// @dev When an epoch is swept
    event EpochSwept(uint epochIndex);

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
     * ..
     */
    function sweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) external;

    /**
     * ..
     */
    function resweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) external;

    /**
     * ..
     */
    function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts, TreasuryEnums.SweepType sweepType) external;

    /**
     * ..
     */
    function minSweepAmount() external returns (uint);

    /**
     * ..
     */
    function mercSweeper() external returns (address);

    /**
     * ..
     */
    function setMercenarySweeper(address _mercSweeper) external;
}
