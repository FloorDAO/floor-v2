// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

import '../authorities/AuthorityControl.sol';

import '../tokens/VeFloor.sol';

import '../../interfaces/staking/VeFloorStaking.sol';
import '../../interfaces/voting/GaugeWeightVote.sol';

/// @title Vote Escrow Floor Staking
/// @author Trader Joe
/// @notice Stake FLOOR to earn veFLOOR, which you can use to earn higher farm yields and gain
/// voting power. Note that unstaking any amount of FLOOR will burn all of your existing veFLOOR.
contract VeFloorStaking is AuthorityControl, IVeFloorStaking, Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    /// @notice Info for each user
    /// `balance`: Amount of FLOOR currently staked by user
    /// `rewardDebt`: The reward debt of the user
    /// `lastClaimTimestamp`: The timestamp of user's last claim or withdraw
    /// `speedUpEndTimestamp`: The timestamp when user stops receiving speed up benefits, or
    /// zero if user is not currently receiving speed up benefits
    struct UserInfo {
        uint balance;
        uint rewardDebt;
        uint lastClaimTimestamp;
        uint speedUpEndTimestamp;
    }
    /**
     * @notice We do some fancy math here. Basically, any point in time, the amount of veFLOOR
     * entitled to a user but is pending to be distributed is:
     *
     *   pendingReward = pendingBaseReward + pendingSpeedUpReward
     *
     *   pendingBaseReward = (user.balance * accVeFloorPerShare) - user.rewardDebt
     *
     *   if user.speedUpEndTimestamp != 0:
     *     speedUpCeilingTimestamp = min(block.timestamp, user.speedUpEndTimestamp)
     *     speedUpSecondsElapsed = speedUpCeilingTimestamp - user.lastClaimTimestamp
     *     pendingSpeedUpReward = speedUpSecondsElapsed * user.balance * speedUpVeFloorPerSharePerSec
     *   else:
     *     pendingSpeedUpReward = 0
     */

    IERC20 public floor;
    veFLOOR public veFloor;
    IGaugeWeightVote public gaugeWeightVote;

    /// @notice The maximum limit of veFLOOR user can have as percentage points of staked FLOOR
    /// For example, if user has `n` FLOOR staked, they can own a maximum of `n * maxCapPct / 100` veFLOOR.
    uint public maxCapPct;

    /// @notice The upper limit of `maxCapPct`
    uint public upperLimitMaxCapPct;

    /// @notice The accrued veFloor per share, scaled to `ACC_VEFLOOR_PER_SHARE_PRECISION`
    uint public accVeFloorPerShare;

    /// @notice Precision of `accVeFloorPerShare`
    uint public ACC_VEFLOOR_PER_SHARE_PRECISION;

    /// @notice The last time that the reward variables were updated
    uint public lastRewardTimestamp;

    /// @notice veFLOOR per sec per FLOOR staked, scaled to `VEFLOOR_PER_SHARE_PER_SEC_PRECISION`
    uint public veFloorPerSharePerSec;

    /// @notice Speed up veFLOOR per sec per FLOOR staked, scaled to `VEFLOOR_PER_SHARE_PER_SEC_PRECISION`
    uint public speedUpVeFloorPerSharePerSec;

    /// @notice The upper limit of `veFloorPerSharePerSec` and `speedUpVeFloorPerSharePerSec`
    uint public upperLimitVeFloorPerSharePerSec;

    /// @notice Precision of `veFloorPerSharePerSec`
    uint public VEFLOOR_PER_SHARE_PER_SEC_PRECISION;

    /// @notice Percentage of user's current staked FLOOR user has to deposit in order to start
    /// receiving speed up benefits, in parts per 100.
    /// @dev Specifically, user has to deposit at least `speedUpThreshold/100 * userStakedFloor` FLOOR.
    /// The only exception is the user will also receive speed up benefits if they are depositing
    /// with zero balance
    uint public speedUpThreshold;

    /// @notice The length of time a user receives speed up benefits
    uint public speedUpDuration;

    mapping(address => UserInfo) public userInfos;

    /// @notice Initialize with needed parameters
    /// @param _floor Address of the FLOOR token contract
    /// @param _veFloor Address of the veFLOOR token contract
    /// @param _veFloorPerSharePerSec veFLOOR per sec per FLOOR staked, scaled to `VEFLOOR_PER_SHARE_PER_SEC_PRECISION`
    /// @param _speedUpVeFloorPerSharePerSec Similar to `_veFloorPerSharePerSec` but for speed up
    /// @param _speedUpThreshold Percentage of total staked FLOOR user has to deposit receive speed up
    /// @param _speedUpDuration Length of time a user receives speed up benefits
    /// @param _maxCapPct Maximum limit of veFLOOR user can have as percentage points of staked FLOOR
    constructor(
        address _authority,
        IERC20 _floor,
        veFLOOR _veFloor,
        IGaugeWeightVote _gaugeWeightVote,
        uint _veFloorPerSharePerSec,
        uint _speedUpVeFloorPerSharePerSec,
        uint _speedUpThreshold,
        uint _speedUpDuration,
        uint _maxCapPct
    ) AuthorityControl(_authority) {
        require(address(_floor) != address(0), 'VeFloorStaking: unexpected zero address for _floor');
        require(address(_veFloor) != address(0), 'VeFloorStaking: unexpected zero address for _veFloor');
        require(address(_gaugeWeightVote) != address(0), 'VeFloorStaking: unexpected zero address for _gaugeWeightVote');

        upperLimitVeFloorPerSharePerSec = 1e36;
        require(
            _veFloorPerSharePerSec <= upperLimitVeFloorPerSharePerSec,
            'VeFloorStaking: expected _veFloorPerSharePerSec to be <= 1e36'
        );
        require(
            _speedUpVeFloorPerSharePerSec <= upperLimitVeFloorPerSharePerSec,
            'VeFloorStaking: expected _speedUpVeFloorPerSharePerSec to be <= 1e36'
        );

        require(
            _speedUpThreshold != 0 && _speedUpThreshold <= 100,
            'VeFloorStaking: expected _speedUpThreshold to be > 0 and <= 100'
        );

        require(_speedUpDuration <= 365 days, 'VeFloorStaking: expected _speedUpDuration to be <= 365 days');

        upperLimitMaxCapPct = 10000000;
        require(
            _maxCapPct != 0 && _maxCapPct <= upperLimitMaxCapPct,
            'VeFloorStaking: expected _maxCapPct to be non-zero and <= 10000000'
        );

        maxCapPct = _maxCapPct;
        speedUpThreshold = _speedUpThreshold;
        speedUpDuration = _speedUpDuration;
        floor = _floor;
        gaugeWeightVote = _gaugeWeightVote;
        veFloor = _veFloor;
        veFloorPerSharePerSec = _veFloorPerSharePerSec;
        speedUpVeFloorPerSharePerSec = _speedUpVeFloorPerSharePerSec;
        lastRewardTimestamp = block.timestamp;
        ACC_VEFLOOR_PER_SHARE_PRECISION = 1e18;
        VEFLOOR_PER_SHARE_PER_SEC_PRECISION = 1e18;
    }

    /// @notice Set maxCapPct
    /// @param _maxCapPct The new maxCapPct
    function setMaxCapPct(uint _maxCapPct) external onlyOwner {
        require(_maxCapPct > maxCapPct, 'VeFloorStaking: expected new _maxCapPct to be greater than existing maxCapPct');
        require(
            _maxCapPct != 0 && _maxCapPct <= upperLimitMaxCapPct,
            'VeFloorStaking: expected new _maxCapPct to be non-zero and <= 10000000'
        );
        maxCapPct = _maxCapPct;
        emit UpdateMaxCapPct(_msgSender(), _maxCapPct);
    }

    /// @notice Set veFloorPerSharePerSec
    /// @param _veFloorPerSharePerSec The new veFloorPerSharePerSec
    function setVeFloorPerSharePerSec(uint _veFloorPerSharePerSec) external onlyOwner {
        require(
            _veFloorPerSharePerSec <= upperLimitVeFloorPerSharePerSec,
            'VeFloorStaking: expected _veFloorPerSharePerSec to be <= 1e36'
        );
        updateRewardVars();
        veFloorPerSharePerSec = _veFloorPerSharePerSec;
        emit UpdateVeFloorPerSharePerSec(_msgSender(), _veFloorPerSharePerSec);
    }

    /// @notice Set speedUpThreshold
    /// @param _speedUpThreshold The new speedUpThreshold
    function setSpeedUpThreshold(uint _speedUpThreshold) external onlyOwner {
        require(
            _speedUpThreshold != 0 && _speedUpThreshold <= 100,
            'VeFloorStaking: expected _speedUpThreshold to be > 0 and <= 100'
        );
        speedUpThreshold = _speedUpThreshold;
        emit UpdateSpeedUpThreshold(_msgSender(), _speedUpThreshold);
    }

    /// @notice Deposits FLOOR to start staking for veFLOOR. Note that any pending veFLOOR
    /// will also be claimed in the process.
    /// @param _amount The amount of FLOOR to deposit
    function deposit(uint _amount) external {
        _deposit(_amount, _msgSender());
    }

    /// @notice Deposits FLOOR to start staking for veFLOOR on behalf of a recipient. This is
    /// a protected function that only specific roles may execute. Note that any pending veFLOOR
    /// will also be claimed in the process.
    /// @param _amount The amount of FLOOR to deposit
    /// @param _recipient Recipient of the veFLOOR
    /// TODO: Needs `onlyRole(STAKING_MANAGER)`
    function depositFor(uint _amount, address _recipient) external {
        _deposit(_amount, _recipient);
    }

    function _deposit(uint _amount, address _recipient) internal {
        require(_amount > 0, 'VeFloorStaking: expected deposit amount to be greater than zero');

        updateRewardVars();

        UserInfo storage userInfo = userInfos[_recipient];

        if (_getUserHasNonZeroBalance(_recipient)) {
            // Transfer to the user their pending veFLOOR before updating their UserInfo
            _claim();

            // We need to update user's `lastClaimTimestamp` to now to prevent
            // passive veFLOOR accrual if user hit their max cap.
            userInfo.lastClaimTimestamp = block.timestamp;

            uint userStakedFloor = userInfo.balance;

            // User is eligible for speed up benefits if `_amount` is at least
            // `speedUpThreshold / 100 * userStakedFloor`
            if (_amount.mul(100) >= speedUpThreshold.mul(userStakedFloor)) {
                userInfo.speedUpEndTimestamp = block.timestamp.add(speedUpDuration);
            }
        } else {
            // If user is depositing with zero balance, they will automatically
            // receive speed up benefits
            userInfo.speedUpEndTimestamp = block.timestamp.add(speedUpDuration);
            userInfo.lastClaimTimestamp = block.timestamp;
        }

        userInfo.balance = userInfo.balance.add(_amount);
        userInfo.rewardDebt = accVeFloorPerShare.mul(userInfo.balance).div(ACC_VEFLOOR_PER_SHARE_PRECISION);

        floor.safeTransferFrom(_msgSender(), address(this), _amount);
        emit Deposit(_recipient, _amount);
    }

    /// @notice Withdraw staked FLOOR. Note that unstaking any amount of FLOOR means you will
    /// lose all of your current veFLOOR.
    /// @param _amount The amount of FLOOR to unstake
    function withdraw(uint _amount) external {
        require(_amount > 0, 'VeFloorStaking: expected withdraw amount to be greater than zero');

        UserInfo storage userInfo = userInfos[_msgSender()];

        require(
            userInfo.balance >= _amount, 'VeFloorStaking: cannot withdraw greater amount of FLOOR than currently staked'
        );
        updateRewardVars();

        // Note that we don't need to claim as the user's veFLOOR balance will be reset to 0
        userInfo.balance = userInfo.balance.sub(_amount);
        userInfo.rewardDebt = accVeFloorPerShare.mul(userInfo.balance).div(ACC_VEFLOOR_PER_SHARE_PRECISION);
        userInfo.lastClaimTimestamp = block.timestamp;
        userInfo.speedUpEndTimestamp = 0;

        // Burn the user's current veFLOOR balance
        uint userVeFloorBalance = veFloor.balanceOf(_msgSender());
        veFloor.burnFrom(_msgSender(), userVeFloorBalance);

        // Send user their requested amount of staked FLOOR
        floor.safeTransfer(_msgSender(), _amount);

        // Remove a user's votes from the Gauge Weight Vote
        gaugeWeightVote.revokeAllUserVotes(_msgSender());

        emit Withdraw(_msgSender(), _amount, userVeFloorBalance);
    }

    /// @notice Claim any pending veFLOOR
    function claim() external {
        require(_getUserHasNonZeroBalance(_msgSender()), 'VeFloorStaking: cannot claim veFLOOR when no FLOOR is staked');
        updateRewardVars();
        _claim();
    }

    /// @notice Get the pending amount of veFLOOR for a given user
    /// @param _user The user to lookup
    /// @return The number of pending veFLOOR tokens for `_user`
    function getPendingVeFloor(address _user) public view returns (uint) {
        if (!_getUserHasNonZeroBalance(_user)) {
            return 0;
        }

        UserInfo memory user = userInfos[_user];

        // Calculate amount of pending base veFLOOR
        uint _accVeFloorPerShare = accVeFloorPerShare;
        uint secondsElapsed = block.timestamp.sub(lastRewardTimestamp);
        if (secondsElapsed > 0) {
            _accVeFloorPerShare = _accVeFloorPerShare.add(
                secondsElapsed.mul(veFloorPerSharePerSec).mul(ACC_VEFLOOR_PER_SHARE_PRECISION).div(
                    VEFLOOR_PER_SHARE_PER_SEC_PRECISION
                )
            );
        }
        uint pendingBaseVeFloor =
            _accVeFloorPerShare.mul(user.balance).div(ACC_VEFLOOR_PER_SHARE_PRECISION).sub(user.rewardDebt);

        // Calculate amount of pending speed up veFLOOR
        uint pendingSpeedUpVeFloor;
        if (user.speedUpEndTimestamp != 0) {
            uint speedUpCeilingTimestamp =
                block.timestamp > user.speedUpEndTimestamp ? user.speedUpEndTimestamp : block.timestamp;
            uint speedUpSecondsElapsed = speedUpCeilingTimestamp.sub(user.lastClaimTimestamp);
            uint speedUpAccVeFloorPerShare = speedUpSecondsElapsed.mul(speedUpVeFloorPerSharePerSec);
            pendingSpeedUpVeFloor = speedUpAccVeFloorPerShare.mul(user.balance).div(VEFLOOR_PER_SHARE_PER_SEC_PRECISION);
        }

        uint pendingVeFloor = pendingBaseVeFloor.add(pendingSpeedUpVeFloor);

        // Get the user's current veFLOOR balance
        uint userVeFloorBalance = veFloor.balanceOf(_user);

        // This is the user's max veFLOOR cap multiplied by 100
        uint scaledUserMaxVeFloorCap = user.balance.mul(maxCapPct);

        if (userVeFloorBalance.mul(100) >= scaledUserMaxVeFloorCap) {
            // User already holds maximum amount of veFLOOR so there is no pending veFLOOR
            return 0;
        } else if (userVeFloorBalance.add(pendingVeFloor).mul(100) > scaledUserMaxVeFloorCap) {
            return scaledUserMaxVeFloorCap.sub(userVeFloorBalance.mul(100)).div(100);
        } else {
            return pendingVeFloor;
        }
    }

    /// @notice Update reward variables
    function updateRewardVars() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        if (floor.balanceOf(address(this)) == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint secondsElapsed = block.timestamp.sub(lastRewardTimestamp);
        accVeFloorPerShare = accVeFloorPerShare.add(
            secondsElapsed.mul(veFloorPerSharePerSec).mul(ACC_VEFLOOR_PER_SHARE_PRECISION).div(
                VEFLOOR_PER_SHARE_PER_SEC_PRECISION
            )
        );
        lastRewardTimestamp = block.timestamp;

        emit UpdateRewardVars(lastRewardTimestamp, accVeFloorPerShare);
    }

    /// @notice Checks to see if a given user currently has staked FLOOR
    /// @param _user The user address to check
    /// @return Whether `_user` currently has staked FLOOR
    function _getUserHasNonZeroBalance(address _user) private view returns (bool) {
        return userInfos[_user].balance > 0;
    }

    /// @dev Helper to claim any pending veFLOOR
    function _claim() private {
        uint veFloorToClaim = getPendingVeFloor(_msgSender());

        UserInfo storage userInfo = userInfos[_msgSender()];

        userInfo.rewardDebt = accVeFloorPerShare.mul(userInfo.balance).div(ACC_VEFLOOR_PER_SHARE_PRECISION);

        // If user's speed up period has ended, reset `speedUpEndTimestamp` to 0
        if (userInfo.speedUpEndTimestamp != 0 && block.timestamp >= userInfo.speedUpEndTimestamp) {
            userInfo.speedUpEndTimestamp = 0;
        }

        if (veFloorToClaim > 0) {
            userInfo.lastClaimTimestamp = block.timestamp;

            veFloor.mint(_msgSender(), veFloorToClaim);
            emit Claim(_msgSender(), veFloorToClaim);
        }
    }
}
