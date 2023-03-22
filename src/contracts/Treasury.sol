// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, TransferFailed} from '@floor/utils/Errors.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyRegistry} from '@floor-interfaces/strategies/StrategyRegistry.sol';
import {IVault} from '@floor-interfaces/vaults/Vault.sol';
import {IGaugeWeightVote} from '@floor-interfaces/voting/GaugeWeightVote.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/**
 * The Treasury will hold all assets.
 */
contract Treasury is AuthorityControl, ERC1155Holder, ITreasury {
    /// ..
    enum ApprovalType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }

    /**
     * ..
     */
    struct Sweep {
        address[] collections;
        uint[] amounts;
        uint allocationBlock;
        uint sweepBlock;
        bool completed;
    }

    /// An array of sweeps that map against the epoch iteration
    mapping(uint => Sweep) public epochSweeps;

    /**
     * ..
     */
    struct ActionApproval {
        ApprovalType _type; // Token type
        address assetContract; // Used by 20, 721 and 1155
        uint tokenId; // Used by 721 tokens
        uint amount; // Used by native and 20 tokens
    }

    /// Holds our {StrategyRegistry} contract reference
    IStrategyRegistry public strategyRegistry;

    /// Holds our {FLOOR} contract reference
    FLOOR public floor;

    /// The amount of our {Treasury} reward yield that is retained. Any remaining percentage
    /// amount will be distributed to the top voted collections via our {GaugeWeightVote} contract.
    uint public retainedTreasuryYieldPercentage;

    /// Store a minimum sweep amount that can be implemented, or excluded, as desired by
    /// the DAO.
    uint public minSweepAmount;

    /**
     * Set up our connection to the Treasury to ensure future calls only come from this
     * trusted source.
     *
     * @param _authority {AuthorityRegistry} contract address
     * @param _strategyRegistry Address of our {StrategyRegistry}
     * @param _floor Address of our {FLOOR}
     */
    constructor(address _authority, address _strategyRegistry, address _floor) AuthorityControl(_authority) {
        strategyRegistry = IStrategyRegistry(_strategyRegistry);
        floor = FLOOR(_floor);
    }

    /**
     * Allow FLOOR token to be minted. This should be called from the deposit method
     * internally, but a public method will allow a {TreasuryManager} to bypass this
     * and create additional FLOOR tokens if needed.
     *
     * @param amount The amount of {FLOOR} tokens to be minted
     */
    function mint(uint amount) external onlyRole(TREASURY_MANAGER) {
        if (amount == 0) {
            revert InsufficientAmount();
        }

        _mint(address(this), amount);
    }

    /**
     * Internal call to handle minting and event firing.
     *
     * @param recipient The recipient of the {FLOOR} tokens
     * @param amount The number of tokens to be minted
     */
    function _mint(address recipient, uint amount) internal {
        floor.mint(recipient, amount);
        emit FloorMinted(amount);
    }

    /**
     * Allows an ERC20 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     *
     * @param token ERC20 token address to be deposited
     * @param amount The amount of the token to be deposited
     */
    function depositERC20(address token, uint amount) external {
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }

        emit DepositERC20(token, amount);
    }

    /**
     * Allows an ERC721 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     *
     * @param token ERC721 token address to be deposited
     * @param tokenId The ID of the ERC721 being deposited
     */
    function depositERC721(address token, uint tokenId) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        emit DepositERC721(token, tokenId);
    }

    /**
     * Allows an ERC1155 token(s) to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     *
     * @param token ERC1155 token address to be deposited
     * @param tokenId The ID of the ERC1155 being deposited
     * @param amount The amount of the token to be deposited
     */
    function depositERC1155(address token, uint tokenId, uint amount) external {
        IERC1155(token).safeTransferFrom(msg.sender, address(this), tokenId, amount, '');
        emit DepositERC1155(token, tokenId, amount);
    }

    /**
     * Allows an approved user to withdraw native token.
     *
     * @param recipient The user that will receive the native token
     * @param amount The number of native tokens to withdraw
     */
    function withdraw(address recipient, uint amount) external onlyRole(TREASURY_MANAGER) {
        (bool success,) = recipient.call{value: amount}('');
        if (!success) {
            revert TransferFailed();
        }

        emit Withdraw(amount, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC20 token from the vault.
     *
     * @param recipient The user that will receive the ERC20 tokens
     * @param token ERC20 token address to be withdrawn
     * @param amount The number of tokens to withdraw
     */
    function withdrawERC20(address recipient, address token, uint amount) external onlyRole(TREASURY_MANAGER) {
        bool success = IERC20(token).transfer(recipient, amount);
        if (!success) {
            revert TransferFailed();
        }

        emit WithdrawERC20(token, amount, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC721 token from the vault.
     *
     * @param recipient The user that will receive the ERC721 tokens
     * @param token ERC721 token address to be withdrawn
     * @param tokenId The ID of the ERC721 being withdrawn
     */
    function withdrawERC721(address recipient, address token, uint tokenId) external onlyRole(TREASURY_MANAGER) {
        IERC721(token).transferFrom(address(this), recipient, tokenId);
        emit WithdrawERC721(token, tokenId, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC1155 token(s) from the vault.
     *
     * @param recipient The user that will receive the ERC1155 tokens
     * @param token ERC1155 token address to be withdrawn
     * @param tokenId The ID of the ERC1155 being withdrawn
     * @param amount The number of tokens to withdraw
     */
    function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external onlyRole(TREASURY_MANAGER) {
        IERC1155(token).safeTransferFrom(address(this), recipient, tokenId, amount, '');
        emit WithdrawERC1155(token, tokenId, amount, recipient);
    }

    /**
     * Sets the percentage of treasury rewards yield to be retained by the treasury, with
     * the remaining percetange distributed to non-treasury vault stakers based on the GWV.
     *
     * @param percent New treasury yield percentage value
     */
    function setRetainedTreasuryYieldPercentage(uint percent) external onlyRole(TREASURY_MANAGER) {
        if (percent > 10000) {
            revert PercentageTooHigh(10000);
        }

        retainedTreasuryYieldPercentage = percent;
    }

    /**
     * Apply an action against the vault.
     *
     * @param action Address of the action to apply
     * @param approvals Any tokens that need to be approved before actioning
     * @param data Any bytes data that should be passed to the {IAction} execution function
     */
    function processAction(address payable action, ActionApproval[] calldata approvals, bytes calldata data)
        external
        onlyRole(TREASURY_MANAGER)
    {
        for (uint i; i < approvals.length;) {
            if (approvals[i]._type == ApprovalType.NATIVE) {
                (bool sent,) = payable(action).call{value: approvals[i].amount}('');
                require(sent, 'Unable to fund action');
            } else if (approvals[i]._type == ApprovalType.ERC20) {
                IERC20(approvals[i].assetContract).approve(action, approvals[i].amount);
            } else if (approvals[i]._type == ApprovalType.ERC721) {
                IERC721(approvals[i].assetContract).approve(action, approvals[i].tokenId);
            } else if (approvals[i]._type == ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(action, true);
            }

            unchecked {
                ++i;
            }
        }

        IAction(action).execute(data);

        // Remove ERC1155 global approval after execution
        for (uint i; i < approvals.length;) {
            if (approvals[i]._type == ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(action, false);
            }
        }
    }

    /**
     * ..
     */
    // TODO: Lock down to only receive from epoch manager
    function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts) external {
        epochSweeps[epoch] = Sweep({collections: collections, amounts: amounts, allocationBlock: block.number, sweepBlock: 0, completed: false});
    }

    /**
     * ..
     */
    function sweepEpoch(uint epochIndex, address sweeper) public onlyRole(TREASURY_MANAGER) {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have a valid sweep index
        require(!epochSweep.completed, 'Epoch sweep already completed');
        require(epochSweep.collections.length != 0, 'No collections to sweep');

        return _sweepEpoch(epochIndex, sweeper, epochSweep);
    }

    /**
     * ..
     */
    function resweepEpoch(uint epochIndex, address sweeper) public onlyRole(TREASURY_MANAGER) {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have a valid sweep index
        require(epochSweep.collections.length != 0, 'No collections to sweep');

        return _sweepEpoch(epochIndex, sweeper, epochSweep);
    }

    /**
     * ..
     */
    function setMinSweepAmount(uint _minSweepAmount) external onlyRole(TREASURY_MANAGER) {
        minSweepAmount = _minSweepAmount;
    }

    /**
     * ..
     */
    function _sweepEpoch(uint epochIndex, address sweeper, Sweep memory epochSweep) internal {
        // Find the total amount to send to the sweeper and transfer it before the call
        uint msgValue;
        for (uint i; i < epochSweep.collections.length;) {
            unchecked {
                msgValue += epochSweep.amounts[i];
                ++i;
            }
        }

        // Action our sweep. If we don't hold enough ETH to supply the message value then
        // we expect this call to revert.
        ISweeper(sweeper).execute{value: msgValue}(epochSweep.collections, epochSweep.amounts);

        // Mark our sweep as completed
        epochSweep.completed = true;
        epochSweep.sweepBlock = block.number;

        epochSweeps[epochIndex] = epochSweep;

        // emit EpochSwept(epochIndex);
    }

    /**
     * Allow our contract to receive native tokens.
     */
    receive() external payable {
        emit Deposit(msg.value);
    }
}
