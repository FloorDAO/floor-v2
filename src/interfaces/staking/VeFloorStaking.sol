// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IVeFloorStaking {

    event Claim(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event UpdateMaxCapPct(address indexed user, uint256 maxCapPct);
    event UpdateRewardVars(uint256 lastRewardTimestamp, uint256 accVeFloorPerShare);
    event UpdateSpeedUpThreshold(address indexed user, uint256 speedUpThreshold);
    event UpdateVeFloorPerSharePerSec(address indexed user, uint256 veFloorPerSharePerSec);
    event Withdraw(address indexed user, uint256 withdrawAmount, uint256 burnAmount);

    /// @notice The maximum limit of veFLOOR user can have as percentage points of staked FLOOR
    /// For example, if user has `n` FLOOR staked, they can own a maximum of `n * maxCapPct / 100` veFLOOR.
    function maxCapPct() external returns (uint256);

    /// @notice The upper limit of `maxCapPct`
    function upperLimitMaxCapPct() external returns (uint256);

    /// @notice The accrued veFloor per share, scaled to `ACC_VEFLOOR_PER_SHARE_PRECISION`
    function accVeFloorPerShare() external returns (uint256);

    /// @notice Precision of `accVeFloorPerShare`
    function ACC_VEFLOOR_PER_SHARE_PRECISION() external returns (uint256);

    /// @notice The last time that the reward variables were updated
    function lastRewardTimestamp() external returns (uint256);

    /// @notice veFLOOR per sec per FLOOR staked, scaled to `VEFLOOR_PER_SHARE_PER_SEC_PRECISION`
    function veFloorPerSharePerSec() external returns (uint256);

    /// @notice Speed up veFLOOR per sec per FLOOR staked, scaled to `VEFLOOR_PER_SHARE_PER_SEC_PRECISION`
    function speedUpVeFloorPerSharePerSec() external returns (uint256);

    /// @notice The upper limit of `veFloorPerSharePerSec` and `speedUpVeFloorPerSharePerSec`
    function upperLimitVeFloorPerSharePerSec() external returns (uint256);

    /// @notice Precision of `veFloorPerSharePerSec`
    function VEFLOOR_PER_SHARE_PER_SEC_PRECISION() external returns (uint256);

    /// @notice Percentage of user's current staked FLOOR user has to deposit in order to start
    /// receiving speed up benefits, in parts per 100.
    /// @dev Specifically, user has to deposit at least `speedUpThreshold/100 * userStakedFloor` FLOOR.
    /// The only exception is the user will also receive speed up benefits if they are depositing
    /// with zero balance
    function speedUpThreshold() external returns (uint256);

    /// @notice The length of time a user receives speed up benefits
    function speedUpDuration() external returns (uint256);

    /// @notice Deposits FLOOR to start staking for veFLOOR. Note that any pending veFLOOR
    /// will also be claimed in the process.
    /// @param _amount The amount of FLOOR to deposit
    function deposit(uint256 _amount) external;

    /// @notice Withdraw staked FLOOR. Note that unstaking any amount of FLOOR means you will
    /// lose all of your current veFLOOR.
    /// @param _amount The amount of FLOOR to unstake
    function withdraw(uint256 _amount) external;

    /// @notice Claim any pending veFLOOR
    function claim() external;

    /// @notice Get the pending amount of veFLOOR for a given user
    /// @param _user The user to lookup
    /// @return The number of pending veFLOOR tokens for `_user`
    function getPendingVeFloor(address _user) external view returns (uint256);

    /// @notice Update reward variables
    function updateRewardVars() external;

}