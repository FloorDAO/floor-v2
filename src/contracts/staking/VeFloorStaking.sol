// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeERC20} from '@1inch/solidity-utils/contracts/libraries/SafeERC20.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';

import {EpochManaged} from '@floor/utils/EpochManaged.sol';

import {IVeFloorStaking, Depositor} from '@floor-interfaces/staking/VeFloorStaking.sol';
import {IERC20, IVotable} from '@floor-interfaces/tokens/Votable.sol';
import {INewCollectionWars} from '@floor-interfaces/voting/NewCollectionWars.sol';
import {ISweepWars} from '@floor-interfaces/voting/SweepWars.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/**
 * @title FLOOR Staking
 * @notice The contract provides the following features: staking, delegation, farming
 * How lock period works:
 * - balances and voting power
 * - Lock min and max
 * - Add lock
 * - earlyWithdrawal
 * - penalty math
 *
 * @dev Based on staked 1inch (St1inch :: 0x9A0C8Ff858d273f57072D714bca7411D717501D7)
 */
contract VeFloorStaking is EpochManaged, ERC20, ERC20Permit, ERC20Votes, IVeFloorStaking, IVotable {

    using SafeERC20 for IERC20;

    event EmergencyExitSet(bool status);
    event MaxLossRatioSet(uint ratio);
    event MinLockPeriodRatioSet(uint ratio);
    event FeeReceiverSet(address receiver);

    event Deposit(address account, uint amount);
    event Withdraw(address sender, uint amount);

    error ApproveDisabled();
    error TransferDisabled();
    error UnlockTimeHasNotCome();
    error StakeUnlocked();
    error MinLockPeriodRatioNotReached();
    error MinReturnIsNotMet();
    error MaxLossIsNotMet();
    error MaxLossOverflow();
    error LossIsTooBig();
    error RescueAmountIsTooLarge();
    error ExpBaseTooBig();
    error ExpBaseTooSmall();
    error DepositsDisabled();
    error ZeroAddress();

    /// Set a list of locking periods that the user can lock for
    uint8[] public LOCK_PERIODS = [uint8(0), 4, 13, 26, 52, 78, 104];

    /// Our FLOOR token
    IERC20 public immutable floor;

    /// Our internal contracts
    ITreasury public immutable treasury;
    INewCollectionWars public newCollectionWars;
    ISweepWars public sweepWars;

    /// Allow some addresses to be exempt from early withdraw fees
    mapping(address => bool) public earlyWithdrawFeeExemptions;

    /// Map our Depositor index against a user
    mapping(address => Depositor) public depositors;

    uint internal constant _ONE_E9 = 1e9;

    uint public totalDeposits;
    bool public emergencyExit;
    uint public maxLossRatio;
    uint public minLockPeriodRatio;
    address public feeReceiver;

    /**
     * @notice Initializes the contract
     * @param floor_ The token to be staked
     * @param treasury_ The treasury contract address
     */
    constructor(IERC20 floor_, address treasury_) ERC20('veFLOOR', 'veFLOOR') ERC20Permit('veFLOOR') {
        floor = floor_;
        treasury = ITreasury(treasury_);
        setFeeReceiver(treasury_);
    }

    /**
     * @notice Sets the new contract that would recieve early withdrawal fees
     * @param feeReceiver_ The receiver contract address
     */
    function setFeeReceiver(address feeReceiver_) public onlyOwner {
        if (feeReceiver_ == address(0)) revert ZeroAddress();
        feeReceiver = feeReceiver_;
        emit FeeReceiverSet(feeReceiver_);
    }

    /**
     * @notice Sets the maximum allowed loss ratio for early withdrawal. If the ratio is not met, actual is more than allowed,
     * then early withdrawal will revert.
     * Example: maxLossRatio = 90% and 1000 staked 1inch tokens means that a user can execute early withdrawal only
     * if his loss is less than or equals 90% of his stake, which is 900 tokens. Thus, if a user loses 900 tokens he is allowed
     * to do early withdrawal and not if the loss is greater.
     * @param maxLossRatio_ The maximum loss allowed (9 decimals).
     */
    function setMaxLossRatio(uint maxLossRatio_) external onlyOwner {
        if (maxLossRatio_ > _ONE_E9) revert MaxLossOverflow();
        maxLossRatio = maxLossRatio_;
        emit MaxLossRatioSet(maxLossRatio_);
    }

    /**
     * @notice Sets the minimum allowed lock period ratio for early withdrawal. If the ratio is not met, actual is more than allowed,
     * then early withdrawal will revert.
     * @param minLockPeriodRatio_ The maximum loss allowed (9 decimals).
     */
    function setMinLockPeriodRatio(uint minLockPeriodRatio_) external onlyOwner {
        if (minLockPeriodRatio_ > _ONE_E9) revert MaxLossOverflow();
        minLockPeriodRatio = minLockPeriodRatio_;
        emit MinLockPeriodRatioSet(minLockPeriodRatio_);
    }

    /**
     * @notice Sets the emergency exit mode. In emergency mode any stake may withdraw its stake regardless of lock.
     * The mode is intended to use only for migration to a new version of staking contract.
     * @param emergencyExit_ set `true` to enter emergency exit mode and `false` to return to normal operations
     */
    function setEmergencyExit(bool emergencyExit_) external onlyOwner {
        emergencyExit = emergencyExit_;
        emit EmergencyExitSet(emergencyExit_);
    }

    /**
     * @notice Gets the voting power of the provided account
     * @param account The address of an account to get voting power for
     * @return votingPower The voting power available at the block timestamp
     */
    function votingPowerOf(address account) external view returns (uint) {
        return this.votingPowerAt(account, currentEpoch());
    }

    /**
     * ..
     */
    function votingPowerAt(address account, uint epoch) external view returns (uint) {
        return this.votingPowerOfAt(account, depositors[account].amount, epoch);
    }

    /**
     * ..
     */
    function votingPowerOfAt(address account, uint88 amount, uint epoch) external view returns (uint) {
        // If the epoch had not started at this point, then we return 0 power
        if (depositors[account].epochStart > epoch) {
            return 0;
        }

        // Calculate the number of epochs that have passed since started
        uint epochDifference = epoch - depositors[account].epochStart;

        // Calculate the full power attributed to the user based on the epoch count
        uint fullPower = (amount * depositors[account].epochCount) / LOCK_PERIODS[LOCK_PERIODS.length - 1];

        // If we only just staked, then they have their full power
        if (epochDifference == 0) {
            return fullPower;
        }

        // If the staking period has expired, then we have 0 power
        if (epochDifference > depositors[account].epochCount) {
            return 0;
        }

        // Otherwise, we can calculate the remaining power, based on the number of epochs
        // that have passed against their full power.
        return (fullPower * (depositors[account].epochCount - epoch)) / depositors[account].epochCount;
    }

    /**
     * @notice Stakes given amount and locks it for the given duration
     */
    function deposit(uint amount, uint epochs) external {
        _deposit(msg.sender, amount, epochs);
    }

    /**
     * @notice Stakes given amount and locks it for the given duration with permit
     */
    function depositWithPermit(uint amount, uint epochs, bytes calldata permit) external {
        floor.safePermit(permit);
        _deposit(msg.sender, amount, epochs);
    }

    /**
     * @notice Stakes given amount on behalf of provided account without locking or extending lock
     * @param account The account to stake for
     * @param amount The amount to stake
     */
    function depositFor(address account, uint amount) external {
        _deposit(account, amount, 0);
    }

    /**
     * @notice Stakes given amount on behalf of provided account without locking or extending
     * lock with permit.
     * @param account The account to stake for
     * @param amount The amount to stake
     * @param permit Permit given by the caller
     */
    function depositForWithPermit(address account, uint amount, bytes calldata permit) external {
        floor.safePermit(permit);
        _deposit(account, amount, 0);
    }

    function _deposit(address account, uint amount, uint epochs) private {
        if (emergencyExit) revert DepositsDisabled();
        Depositor memory depositor = depositors[account]; // SLOAD
        require(epochs < LOCK_PERIODS.length, 'Invalid epoch index');

        // Update the user's lock
        if (epochs != 0) {
            depositor.epochStart = uint160(currentEpoch());
            depositor.epochCount = LOCK_PERIODS[epochs];
        }

        depositor.amount += uint88(amount);
        depositors[account] = depositor; // SSTORE

        // Increase our total deposits
        totalDeposits += amount;

        // If we are staking additional tokens, then transfer the based FLOOR from the user
        // and mint veFloor tokens to the recipient `account`.
        if (amount > 0) {
            floor.safeTransferFrom(msg.sender, address(this), amount);
            _mint(account, amount);
        }

        emit Deposit(account, amount);
    }

    /**
     * @notice Withdraw stake before lock period expires at the cost of losing part of a stake.
     * The stake loss is proportional to the time passed from the maximum lock period to the lock expiration and voting power.
     * The more time is passed the less would be the loss.
     * Formula to calculate return amount = (deposit - voting power)) / 0.95
     * @param minReturn The minumum amount of stake acceptable for return. If actual amount is less then the transaction is reverted
     * @param maxLoss The maximum amount of loss acceptable. If actual loss is bigger then the transaction is reverted
     */
    function earlyWithdraw(uint minReturn, uint maxLoss) external {
        earlyWithdrawTo(msg.sender, minReturn, maxLoss);
    }

    /**
     * @notice Withdraw stake before lock period expires at the cost of losing part of a stake to the specified account
     * The stake loss is proportional to the time passed from the maximum lock period to the lock expiration and voting power.
     * The more time is passed the less would be the loss.
     * Formula to calculate return amount = (deposit - voting power)) / 0.95
     * @param to The account to withdraw the stake to
     * @param minReturn The minumum amount of stake acceptable for return. If actual amount is less then the transaction is reverted
     * @param maxLoss The maximum amount of loss acceptable. If actual loss is bigger then the transaction is reverted
     */
    function earlyWithdrawTo(address to, uint minReturn, uint maxLoss) public {
        Depositor memory depositor = depositors[msg.sender]; // SLOAD
        if (emergencyExit || currentEpoch() >= depositor.epochStart + depositor.epochCount) revert StakeUnlocked();
        uint allowedExitTime = depositor.epochStart + (depositor.epochCount - depositor.epochStart) * minLockPeriodRatio / _ONE_E9;
        if (currentEpoch() < allowedExitTime) revert MinLockPeriodRatioNotReached();

        // Get the amount that has been deposited and ensure that there is an amount to
        // be withdrawn at all.
        uint amount = depositor.amount;
        if (amount == 0) {
            return;
        }

        // Check if the called is exempt from being required to pay early withdrawal fees
        if (this.isExemptFromEarlyWithdrawFees(msg.sender)) {
            _withdraw(depositor, amount);
            floor.safeTransfer(to, amount);
            return;
        }

        (uint loss, uint ret) = _earlyWithdrawLoss(msg.sender, amount, this.votingPowerOf(msg.sender));

        if (ret < minReturn) revert MinReturnIsNotMet();
        if (loss > maxLoss) revert MaxLossIsNotMet();
        if (loss > amount * maxLossRatio / _ONE_E9) revert LossIsTooBig();

        _withdraw(depositor, amount);
        floor.safeTransfer(to, ret);
        floor.safeTransfer(feeReceiver, loss);
    }

    /**
     * @notice Gets the loss amount if the staker do early withdrawal at the current block
     * @param account The account to calculate early withdrawal loss for
     * @return loss The loss amount
     * @return ret The return amount
     * @return canWithdraw True if the staker can withdraw without penalty, false otherwise
     */
    function earlyWithdrawLoss(address account) external view returns (uint loss, uint ret, bool canWithdraw) {
        uint amount = depositors[account].amount;
        (loss, ret) = _earlyWithdrawLoss(account, amount, this.votingPowerOf(account));
        canWithdraw = loss <= amount * maxLossRatio / _ONE_E9;
    }

    function _earlyWithdrawLoss(address account, uint depAmount, uint stBalance) private view returns (uint loss, uint ret) {
        ret = depAmount - this.votingPowerOfAt(account, uint88(stBalance), currentEpoch());
        loss = depAmount - ret;
    }

    /**
     * @notice Withdraws stake if lock period expired
     */
    function withdraw() external {
        withdrawTo(msg.sender);
    }

    /**
     * @notice Withdraws stake if lock period expired to the given address
     */
    function withdrawTo(address to) public {
        Depositor memory depositor = depositors[msg.sender]; // SLOAD
        if (!emergencyExit && currentEpoch() < depositor.epochStart + depositor.epochCount) revert UnlockTimeHasNotCome();

        uint amount = depositor.amount;
        if (amount > 0) {
            _withdraw(depositor, balanceOf(msg.sender));
            floor.safeTransfer(to, amount);
        }
    }

    /**
     * ..
     */
    function _withdraw(Depositor memory depositor, uint balance) private {
        totalDeposits -= depositor.amount;
        depositor.amount = 0;
        depositors[msg.sender] = depositor; // SSTORE

        if (address(newCollectionWars) != address(0)) {
            newCollectionWars.revokeVotes(msg.sender);
        }

        if (address(sweepWars) != address(0)) {
            sweepWars.revokeAllUserVotes(msg.sender);
        }

        _burn(msg.sender, balance);

        emit Withdraw(msg.sender, depositor.amount);
    }

    /**
     * ..
     */
    function setVotingContracts(address _newCollectionWars, address _sweepWars) external onlyOwner {
        newCollectionWars = INewCollectionWars(_newCollectionWars);
        sweepWars = ISweepWars(_sweepWars);
    }

    /**
     * @notice Retrieves funds from the contract in emergency situations
     * @param token The token to retrieve
     * @param amount The amount of funds to transfer
     */
    function rescueFunds(IERC20 token, uint amount) external onlyOwner {
        if (address(token) == address(0)) {
            Address.sendValue(payable(msg.sender), amount);
        } else {
            if (token == floor) {
                if (amount > floor.balanceOf(address(this)) - totalDeposits) revert RescueAmountIsTooLarge();
            }
            token.safeTransfer(msg.sender, amount);
        }
    }

    /**
     * ..
     */
    function isExemptFromEarlyWithdrawFees(address account) external view returns (bool) {
        return earlyWithdrawFeeExemptions[account];
    }

    /**
     * ..
     */
    function addEarlyWithdrawFeeExemption(address account, bool exempt) external onlyOwner {
        earlyWithdrawFeeExemptions[account] = exempt;
    }

    // ERC20 methods disablers

    function approve(address, uint) public pure override (IERC20, ERC20) returns (bool) {
        revert ApproveDisabled();
    }

    function transfer(address, uint) public pure override (IERC20, ERC20) returns (bool) {
        revert TransferDisabled();
    }

    function transferFrom(address, address, uint) public pure override (IERC20, ERC20) returns (bool) {
        revert TransferDisabled();
    }

    function increaseAllowance(address, uint) public pure override returns (bool) {
        revert ApproveDisabled();
    }

    function decreaseAllowance(address, uint) public pure override returns (bool) {
        revert ApproveDisabled();
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

}
