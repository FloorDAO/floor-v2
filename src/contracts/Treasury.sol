// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';
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
contract Treasury is AuthorityControl, EpochManaged, ERC1155Holder, ITreasury {
    /// Different approval types that can be specified.
    enum ApprovalType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }

    /// Stores data that allows the Treasury to action a sweep.
    struct Sweep {
        address[] collections;
        uint[] amounts;
        uint allocationBlock;
        uint sweepBlock;
        bool completed;
        bytes32 message;
    }

    /// The data structure format that will be mapped against to define a token
    /// approval request.
    struct ActionApproval {
        ApprovalType _type; // Token type
        address assetContract; // Used by 20, 721 and 1155
        uint tokenId; // Used by 721 tokens
        uint amount; // Used by native and 20 tokens
    }

    /// An array of sweeps that map against the epoch iteration.
    mapping(uint => Sweep) public epochSweeps;

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
     * Apply an action against the vault. If we need any tokens to be approved before the
     * action is called, then these are approved before our call and approval is removed
     * afterwards for 1155s.
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
     * When an epoch ends, we have the ability to register a sweep against the {Treasury}
     * via the {EpochManager}. This will store a DAO sweep that will need to be actioned
     * using the `sweepEpoch` function.
     *
     * @param epoch The current epoch that the sweep is generated from
     * @param collections The collections that will be swept
     * @param amounts The amount of ETH to sweep against each collection
     */
    function registerSweep(
        uint epoch,
        address[] calldata collections,
        uint[] calldata amounts
    ) external onlyEpochManager {
        epochSweeps[epoch] = Sweep({
            collections: collections,
            amounts: amounts,
            allocationBlock: block.number,
            sweepBlock: 0,
            completed: false,
            message: ''
        });
    }

    /**
     * Actions a sweep to be used against a contract that implements {ISweeper}. This
     * will fulfill the sweep and we then mark the sweep as completed.
     *
     * @param epochIndex The index of the `epochSweeps`
     * @param sweeper The address of the sweeper contract to be used
     * @param data Additional meta data to send to the sweeper
     */
    function sweepEpoch(uint epochIndex, address sweeper, bytes calldata data) public onlyRole(TREASURY_MANAGER) {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have a valid sweep index
        require(!epochSweep.completed, 'Epoch sweep already completed');
        require(epochSweep.collections.length != 0, 'No collections to sweep');

        return _sweepEpoch(epochIndex, sweeper, epochSweep, data);
    }

    /**
     * Allows the DAO to resweep an already swept "Sweep" struct, using a contract that
     * implements {ISweeper}. This will fulfill the sweep again and keep the sweep marked
     * as completed.
     *
     * @dev This should only be used if there was an unexpected issue with the initial
     * sweep that resulted in assets not being correctly acquired, but the epoch being
     * marked as swept.
     *
     * @param epochIndex The index of the `epochSweeps`
     * @param sweeper The address of the sweeper contract to be used
     * @param data Additional meta data to send to the sweeper
     */
    function resweepEpoch(uint epochIndex, address sweeper, bytes calldata data) public onlyRole(TREASURY_MANAGER) {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have a valid sweep index
        require(epochSweep.collections.length != 0, 'No collections to sweep');

        return _sweepEpoch(epochIndex, sweeper, epochSweep, data);
    }

    /**
     * Allows us to set a minimum amount of ETH to sweep with, so that if the yield
     * allocated to the sweep is too low to be beneficial, then the DAO can stomache
     * the additional cost.
     *
     * @param _minSweepAmount The minimum amount of ETH to sweep with
     */
    function setMinSweepAmount(uint _minSweepAmount) external onlyRole(TREASURY_MANAGER) {
        minSweepAmount = _minSweepAmount;
    }

    /**
     * Handles the logic to action a sweep.
     */
    function _sweepEpoch(uint epochIndex, address sweeper, Sweep memory epochSweep, bytes calldata data) internal {
        // Find the total amount to send to the sweeper and transfer it before the call
        uint msgValue;
        uint length = epochSweep.collections.length;
        for (uint i; i < length;) {
            msgValue += epochSweep.amounts[i];
            unchecked { ++i; }
        }

        // Action our sweep. If we don't hold enough ETH to supply the message value then
        // we expect this call to revert. This call may optionally return a message that
        // will be stored against the struct.
        bytes32 message = ISweeper(sweeper).execute{value: msgValue}(
            epochSweep.collections,
            epochSweep.amounts,
            data
        );

        // Mark our sweep as completed
        epochSweep.completed = true;
        epochSweep.sweepBlock = block.number;

        // If we returned a message, then we write it to our sweep
        if (message != '') {
            epochSweep.message = message;
        }

        // Write our sweep
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
