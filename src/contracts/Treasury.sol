// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {IERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol';
import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {EpochManaged} from '@floor/utils/EpochManaged.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, TransferFailed} from '@floor/utils/Errors.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {IMercenarySweeper, ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

/**
 * The Treasury will hold all assets.
 */
contract Treasury is AuthorityControl, EpochManaged, IERC721Receiver, IERC1155Receiver, ITreasury, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// An array of sweeps that map against the epoch iteration.
    mapping(uint => Sweep) public epochSweeps;

    /// Holds our {FLOOR} and {WETH} contract references.
    FLOOR public immutable floor;
    IWETH public immutable weth;

    /// Holds our {StrategyFactory} contract reference.
    StrategyFactory public strategyFactory;

    /// Holds our {VeFloorStaking} contract reference.
    VeFloorStaking public veFloor;

    /// Store a minimum sweep amount that can be implemented, or excluded, as desired by
    /// the DAO.
    uint public minSweepAmount;

    /// Set a sweep power that is required for public sweep execution
    uint public constant SWEEP_EXECUTE_TOKENS = 5_000 ether;

    /// Stores our Mercenary sweeper contract address
    IMercenarySweeper public mercSweeper;

    /// Stores a list of approved sweeper contracts
    mapping(address => bool) public approvedSweepers;

    /**
     * Set up our connection to the Treasury to ensure future calls only come from this
     * trusted source.
     *
     * @param _authority {AuthorityRegistry} contract address
     * @param _floor Address of our {FLOOR} contract
     * @param _weth Address of {WETH} contract
     */
    constructor(address _authority, address _floor, address _weth) AuthorityControl(_authority) {
        if (_floor == address(0) || _weth == address(0)) revert CannotSetNullAddress();

        floor = FLOOR(_floor);
        weth = IWETH(_weth);
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
     * Allows an ERC20 token to be deposited.
     *
     * @param token ERC20 token address to be deposited
     * @param amount The amount of the token to be deposited
     */
    function depositERC20(address token, uint amount) external {
        // Transfer ERC20 tokens into the {Treasury}. This call will revert if it fails.
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit DepositERC20(token, amount);
    }

    /**
     * Allows an ERC721 token to be deposited.
     *
     * @param token ERC721 token address to be deposited
     * @param tokenId The ID of the ERC721 being deposited
     */
    function depositERC721(address token, uint tokenId) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        emit DepositERC721(token, tokenId);
    }

    /**
     * Allows an ERC1155 token(s) to be deposited.
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
    function withdraw(address recipient, uint amount) external nonReentrant onlyRole(TREASURY_MANAGER) {
        (bool success,) = recipient.call{value: amount}('');
        if (!success) {
            revert TransferFailed();
        }

        emit Withdraw(amount, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC20 token from the Treasury.
     *
     * @param recipient The user that will receive the ERC20 tokens
     * @param token ERC20 token address to be withdrawn
     * @param amount The number of tokens to withdraw
     */
    function withdrawERC20(address recipient, address token, uint amount) external nonReentrant onlyRole(TREASURY_MANAGER) {
        // Transfer ERC20 tokens to the recipient. This call will revert if it fails.
        IERC20(token).safeTransfer(recipient, amount);
        emit WithdrawERC20(token, amount, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC721 token from the Treasury.
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
     * Allows an approved user to withdraw an ERC1155 token(s) from the Treasury.
     *
     * @param recipient The user that will receive the ERC1155 tokens
     * @param token ERC1155 token address to be withdrawn
     * @param tokenId The ID of the ERC1155 being withdrawn
     * @param amount The number of tokens to withdraw
     */
    function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external nonReentrant onlyRole(TREASURY_MANAGER) {
        IERC1155(token).safeTransferFrom(address(this), recipient, tokenId, amount, '');
        emit WithdrawERC1155(token, tokenId, amount, recipient);
    }

    /**
     * Allows the {Treasury} to make a deposit directly into a {BaseStrategy} using
     * the strategy ID. The function selector will need to be included in the `_data`
     * parameter, along with the deposit related parameters.
     *
     * @param _strategyId The ID of the strategy to be depositted into
     * @param _data Any bytes data that should be passed to the {IAction} execution function
     * @param approvals Any tokens that need to be approved before actioning
     */
    function strategyDeposit(
        uint _strategyId,
        bytes calldata _data,
        ActionApproval[] calldata approvals
    ) external nonReentrant onlyRole(TREASURY_MANAGER) {
        // Get our strategy address from the ID
        address strategy = strategyFactory.strategy(_strategyId);
        require(strategy != address(0), 'Invalid strategy');

        uint ethValue;

        uint approvalsLength = approvals.length;
        for (uint i; i < approvalsLength;) {
            if (approvals[i]._type == TreasuryEnums.ApprovalType.NATIVE) {
                ethValue += approvals[i].amount;
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC20) {
                IERC20(approvals[i].assetContract).approve(approvals[i].target, approvals[i].amount);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC721) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(approvals[i].target, true);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(approvals[i].target, true);
            }

            unchecked {
                ++i;
            }
        }

        // Action our call against the target recipient
        (bool success,) = strategy.call{value: ethValue}(_data);
        require(success, 'Transaction failed');

        // Remove approvals after execution
        for (uint i; i < approvalsLength;) {
            if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC20) {
                IERC20(approvals[i].assetContract).approve(approvals[i].target, 0);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC721) {
                IERC721(approvals[i].assetContract).setApprovalForAll(approvals[i].target, false);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(approvals[i].target, false);
            }

            unchecked { ++i; }
        }
    }

    /**
     * Apply an action against the Treasury. If we need any tokens to be approved before the
     * action is called, then these are approved before our call and approval is removed
     * afterwards for 1155s.
     *
     * @param action Address of the action to apply
     * @param approvals Any tokens that need to be approved before actioning
     * @param data Any bytes data that should be passed to the {IAction} execution function
     */
    function processAction(
        address payable action,
        ActionApproval[] calldata approvals,
        bytes calldata data,
        uint linkedSweepEpoch
    )
        external
        nonReentrant
        onlyRole(TREASURY_MANAGER)
    {
        uint ethValue;

        uint approvalsLength = approvals.length;
        for (uint i; i < approvalsLength;) {
            if (approvals[i]._type == TreasuryEnums.ApprovalType.NATIVE) {
                ethValue += approvals[i].amount;
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC20) {
                IERC20(approvals[i].assetContract).approve(approvals[i].target, approvals[i].amount);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC721) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(approvals[i].target, true);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(approvals[i].target, true);
            }

            unchecked {
                ++i;
            }
        }

        IAction(action).execute{value: ethValue}(data);

        // Remove approvals after execution
        for (uint i; i < approvalsLength;) {
            if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC20) {
                IERC20(approvals[i].assetContract).approve(approvals[i].target, 0);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC721) {
                IERC721(approvals[i].assetContract).setApprovalForAll(approvals[i].target, false);
            } else if (approvals[i]._type == TreasuryEnums.ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(approvals[i].target, false);
            }

            unchecked { ++i; }
        }

        emit ActionProcessed(action, data);

        // If we have a sweep epoch index, then we can emit an event that will link the transaction
        // to the epoch. This won't work for epoch 0, but we basically skip that one.
        if (linkedSweepEpoch > 0) {
            emit SweepAction(linkedSweepEpoch);
        }
    }

    /**
     * When an epoch ends, we have the ability to register a sweep against the {Treasury}
     * via an approved contract. This will store a DAO sweep that will need to be actioned
     * using the `sweepEpoch` function.
     *
     * @param epoch The current epoch that the sweep is generated from
     * @param collections The collections that will be swept
     * @param amounts The amount of ETH to sweep against each collection
     */
    function registerSweep(uint epoch, address[] calldata collections, uint[] calldata amounts, TreasuryEnums.SweepType sweepType)
        external
        onlyRole(EPOCH_TRIGGER)
    {
        // Ensure that the epoch does not already have a completed sweep registered
        require(!epochSweeps[epoch].completed, 'Epoch sweep already registered');

        // Confirm that each collection has an amount
        require(collections.length == amounts.length, 'Collections =/= amounts');

        // Ensure that the sweep is not registered in the past
        require(epoch >= currentEpoch(), 'Invalid sweep epoch');

        // Register our sweep against the epoch. This value can be overwritten if another sweep
        // is posted against the epoch, so this should be kept in mind during development.
        epochSweeps[epoch] = Sweep({sweepType: sweepType, collections: collections, amounts: amounts, completed: false, message: ''});

        emit SweepRegistered(epoch, sweepType, collections, amounts);
    }

    /**
     * Actions a sweep to be used against a contract that implements {ISweeper}. This
     * will fulfill the sweep and we then mark the sweep as completed.
     *
     * @param epochIndex The index of the `epochSweeps`
     * @param sweeper The address of the sweeper contract to be used
     * @param data Additional meta data to send to the sweeper
     */
    function sweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) public nonReentrant {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have not already swept this epoch
        require(!epochSweep.completed, 'Epoch sweep already completed');

        /**
         * Checks if the Epoch grace period has expired. This gives the DAO 1 epoch to action
         * the sweep before allowing an external party to action on their behalf.
         *
         *  Sweep       Current
         *  3           3           Not ended yet
         *  3           4           Only DAO
         *  3           5           DAO or 5,000 staked FLOOR power
         *
         * If the grace period has ended, then a user that holds 5,000 staked FLOOR power
         * tokens can action the sweep to take place.
         */

        uint _currentEpoch = currentEpoch();

        // First we need to check that the epoch index has finished
        require(epochIndex < _currentEpoch, 'Epoch has not finished');

        // We can then assume that a `TreasuryManager` can always sweep the epoch
        if (!hasRole(this.TREASURY_MANAGER(), msg.sender)) {
            // If we are in the subsequent epoch, then we cannot allow a non-DAO sweep
            if (address(veFloor) == address(0) || epochIndex + 1 == _currentEpoch) {
                revert('Only DAO may currently execute');
            }

            // If we are beyond the subsequent epoch, then anyone with a locked voting
            // power of 5000 tokens can execute.
            require(veFloor.votingPowerOf(msg.sender) >= SWEEP_EXECUTE_TOKENS, 'Insufficient FLOOR holding');
        }

        return _sweepEpoch(epochIndex, sweeper, epochSweep, data, mercSweep);
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
    function resweepEpoch(uint epochIndex, address sweeper, bytes calldata data, uint mercSweep) public onlyRole(TREASURY_MANAGER) nonReentrant {
        // Ensure that the epoch has already been swept. This ensures that we don't have to
        // implement the same epoch constraints as these would have been present in the
        // initial sweep.
        require(epochSweeps[epochIndex].completed, 'Epoch not swept');

        return _sweepEpoch(epochIndex, sweeper, epochSweeps[epochIndex], data, mercSweep);
    }

    /**
     * Handles the logic to action a sweep.
     */
    function _sweepEpoch(uint epochIndex, address sweeper, Sweep memory epochSweep, bytes calldata data, uint mercSweep) internal burnFloorTokens {
        uint msgValue;
        uint collectionsLength = epochSweep.collections.length;

        // Ensure we have a valid sweep index
        require(collectionsLength != 0, 'No collections to sweep');

        // Confirm that our sweeper has been approved
        require(approvedSweepers[sweeper], 'Sweeper contract not approved');

        // Ensure that the caller has sufficient permissions
        {
            bytes32 sweeperPermissions = ISweeper(sweeper).permissions();
            require(sweeperPermissions == '' || hasRole(sweeperPermissions, msg.sender), 'Invalid sweeper permissions');
        }

        // Add some additional logic around mercSweep specification and exit the process
        // early to save wasted gas.
        if (mercSweep != 0) {
            require(epochSweep.sweepType == TreasuryEnums.SweepType.COLLECTION_ADDITION, 'Merc Sweep only available for collection additions');
            require(address(mercSweeper) != address(0), 'Merc Sweeper not set');

            msgValue = epochSweep.amounts[0];
            require(mercSweep <= msgValue, 'Merc Sweep cannot be higher than msg.value');
        } else {
            // If this is COLLECTION_ADDITION, we will only ever a single collection, so
            // no need for a loop.
            if (epochSweep.sweepType == TreasuryEnums.SweepType.COLLECTION_ADDITION) {
                msgValue = epochSweep.amounts[0];
            } else {
                // Find the total amount to send to the sweeper and transfer it before the call. We
                // should always have at least one amount in the sweep, so we can save gas with a
                // dowhile loop.
                uint i;
                do {
                    msgValue += epochSweep.amounts[i];
                    unchecked {
                        ++i;
                    }
                } while (i < collectionsLength);
            }
        }

        // Check if we have sufficient ETH holdings and then withdraw the required
        // remaining from WETH to power the upcoming sweep.
        uint ethBalance = address(this).balance;
        if (msgValue > ethBalance) {
            weth.withdraw(msgValue - ethBalance);
        }

        // If we have specified mercenary staked NFTs to be swept then we need to
        // action that sweep and remove the value swept from the future sweep amount.
        if (mercSweep != 0) {
            // Fire our request to our mercenary sweeper contract, which will return the
            // amount actually spent on the sweep. We should only have a single value in
            // the collections and amounts arrays, but the sweeper will handle this.
            uint spend = mercSweeper.execute{value: msgValue}(epochManager.collectionEpochs(epochIndex), mercSweep);

            // Reduce the remaining message value sent to the subsequent sweeper
            unchecked { msgValue -= spend; }
            epochSweep.amounts[0] = msgValue;
        }

        // Mark our sweep as completed
        epochSweep.completed = true;

        // Action our sweep. If we don't hold enough ETH to supply the message value then
        // we expect this call to revert. This call may optionally return a message that
        // will be stored against the struct.
        epochSweep.message = ISweeper(sweeper).execute{value: msgValue}(epochSweep.collections, epochSweep.amounts, data);

        // Write our sweep
        epochSweeps[epochIndex] = epochSweep;

        // Fire an event for anyone listening to sweeps
        emit EpochSwept(epochIndex);
    }

    /**
     * Allows the mercenary sweeper contract to be updated.
     *
     * @dev We allow for a zero-address as this will disable the functionality.
     *
     * @param _mercSweeper the new {IMercenarySweeper} contract
     */
    function setMercenarySweeper(address _mercSweeper) external onlyRole(TREASURY_MANAGER) {
        mercSweeper = IMercenarySweeper(_mercSweeper);
        emit MercenarySweeperUpdated(_mercSweeper);
    }

    /**
     * Allows a sweeper contract to be approved or uapproved. This must be done before
     * a contract can be referenced in the `sweepEpoch` and `resweepEpoch` calls.
     *
     * @param _sweeper The address of the sweeper contract
     * @param _approved True to approve, False to unapprove
     */
    function approveSweeper(address _sweeper, bool _approved) external onlyRole(TREASURY_MANAGER) {
        if (_sweeper == address(0)) revert CannotSetNullAddress();
        approvedSweepers[_sweeper] = _approved;
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
        emit MinSweepAmountUpdated(_minSweepAmount);
    }

    /**
     * Allows us to set a new VeFloorStaking contract that is used when sweeping epochs.
     *
     * @dev We allow this to be a zero-address to disable public sweeping
     *
     * @param _veFloorStaking New VeFloorStaking contract
     */
    function setVeFloorStaking(address _veFloorStaking) external onlyRole(TREASURY_MANAGER) {
        veFloor = VeFloorStaking(_veFloorStaking);
        emit VeFloorStakingUpdated(_veFloorStaking);
    }

    /**
     * Allows us to set a new {StrategyFactory} contract that is used when making strategy deposits.
     *
     * @param _strategyFactory New StrategyFactory contract address
     */
    function setStrategyFactory(address _strategyFactory) external onlyRole(TREASURY_MANAGER) {
        if (_strategyFactory == address(0)) revert CannotSetNullAddress();
        strategyFactory = StrategyFactory(_strategyFactory);
        emit StrategyFactoryUpdated(_strategyFactory);
    }

    /**
     * Checks if any FLOOR tokens have been received during the transaction and then
     * burns them afterwards.
     */
    modifier burnFloorTokens() {
        uint startBalance = floor.balanceOf(address(this));

        _;

        uint endBalance = floor.balanceOf(address(this));
        if (endBalance > startBalance) {
            unchecked {
                floor.burn(endBalance - startBalance);
            }
        }
    }

    /**
     * If we receive a direct ERC721 safeTransfer, then we additionally need to handle this
     * and fire an event.
     */
    function onERC721Received(address token, address, uint tokenId, bytes memory) public virtual returns (bytes4) {
        emit DepositERC721(token, tokenId);
        return this.onERC721Received.selector;
    }

    /**
     * If we receive a direct ERC1155 safeTransfer, then we additionally need to handle this
     * and fire an event.
     */
    function onERC1155Received(address token, address, uint tokenId, uint amount, bytes memory) public virtual override returns (bytes4) {
        emit DepositERC1155(token, tokenId, amount);
        return this.onERC1155Received.selector;
    }

    /**
     * If we receive a direct batch of ERC1155 safeTransfer, then we additionally need to
     * handle this and fire an event for each token received.
     */
    function onERC1155BatchReceived(address token, address, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory) public virtual override returns (bytes4) {
        for (uint i; i < tokenIds.length;) {
            emit DepositERC1155(token, tokenIds[i], amounts[i]);
            unchecked { ++i; }
        }

        return this.onERC1155BatchReceived.selector;
    }

    /**
     * Expose that we support interfaces for ERC721 and ERC1155 safeTramsfer.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return (
            interfaceId == this.onERC721Received.selector ||
            interfaceId == this.onERC1155Received.selector ||
            interfaceId == this.onERC1155BatchReceived.selector
        );
    }

    /**
     * Allow our contract to receive native tokens.
     */
    receive() external payable {
        emit Deposit(msg.value);
    }
}
