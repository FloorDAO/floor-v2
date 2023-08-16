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

    /// @dev When an ERC20 is depositted into the Treasury
    event DepositERC20(address token, uint amount);

    /// @dev When an ERC721 is depositted into the Treasury
    event DepositERC721(address token, uint tokenId);

    /// @dev When an ERC1155 is depositted into the Treasury
    event DepositERC1155(address token, uint tokenId, uint amount);

    /// @dev When native network token is withdrawn from the Treasury
    event Withdraw(uint amount, address recipient);

    /// @dev When an ERC20 token is withdrawn from the Treasury
    event WithdrawERC20(address token, uint amount, address recipient);

    /// @dev When an ERC721 token is withdrawn from the Treasury
    event WithdrawERC721(address token, uint tokenId, address recipient);

    /// @dev When an ERC1155 is withdrawn from the Treasury
    event WithdrawERC1155(address token, uint tokenId, uint amount, address recipient);

    /// @dev When FLOOR is minted
    event FloorMinted(uint amount);

    /// @dev When a {Treasury} action is processed
    event ActionProcessed(address action, bytes data);

    /// @dev When a sweep is registered against an epoch
    event SweepRegistered(uint sweepEpoch, TreasuryEnums.SweepType sweepType, address[] collections, uint[] amounts);

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
     * Allows an approved user to withdraw and ERC20 token from the Treasury.
     */
    function withdrawERC20(address recipient, address token, uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC721 token from the Treasury.
     */
    function withdrawERC721(address recipient, address token, uint tokenId) external;

    /**
     * Allows an approved user to withdraw an ERC1155 token(s) from the Treasury.
     */
    function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external;

    /**
     * Actions a sweep to be used against a contract that implements {ISweeper}. This
     * will fulfill the sweep and we then mark the sweep as completed.
     */
    function sweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) external;

    /**
     * Allows the DAO to resweep an already swept "Sweep" struct, using a contract that
     * implements {ISweeper}. This will fulfill the sweep again and keep the sweep marked
     * as completed.
     */
    function resweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) external;

    /**
     * When an epoch ends, we have the ability to register a sweep against the {Treasury}
     * via an approved contract. This will store a DAO sweep that will need to be actioned
     * using the `sweepEpoch` function.
     */
    function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts, TreasuryEnums.SweepType sweepType)
        external;

    /**
     * The minimum sweep amount that can be implemented, or excluded, as desired by the DAO.
     */
    function minSweepAmount() external returns (uint);

    /**
     * Allows the mercenary sweeper contract to be updated.
     */
    function setMercenarySweeper(address _mercSweeper) external;
}
