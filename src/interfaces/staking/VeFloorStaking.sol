// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Depositor {
    uint160 epochStart;
    uint8 epochCount;
    uint88 amount;
}

interface IVeFloorStaking {
    /// Set a list of locking periods that the user can lock for
    function LOCK_PERIODS(uint) external returns (uint8);

    // function floor() external returns (IERC20);

    function earlyWithdrawFeeExemptions(address) external returns (bool);

    function depositors(address) external returns (uint160, uint8, uint88);

    function totalDeposits() external returns (uint);

    function emergencyExit() external returns (bool);

    function maxLossRatio() external returns (uint);

    function minLockPeriodRatio() external returns (uint);

    function feeReceiver() external returns (address);

    function setFeeReceiver(address feeReceiver_) external;

    function setMaxLossRatio(uint maxLossRatio_) external;

    function setMinLockPeriodRatio(uint minLockPeriodRatio_) external;

    function setEmergencyExit(bool emergencyExit_) external;

    // function votingPowerOf(address account) external view returns (uint);

    function votingPowerAt(address account, uint epoch) external view returns (uint);

    function votingPowerOfAt(address account, uint88 amount, uint epoch) external view returns (uint);

    function deposit(uint amount, uint epochs) external;

    function depositWithPermit(uint amount, uint epochs, bytes calldata permit) external;

    function depositFor(address account, uint amount) external;

    function depositForWithPermit(address account, uint amount, bytes calldata permit) external;

    function earlyWithdraw(uint minReturn, uint maxLoss) external;

    function earlyWithdrawTo(address to, uint minReturn, uint maxLoss) external;

    function earlyWithdrawLoss(address account) external view returns (uint loss, uint ret, bool canWithdraw);

    function withdraw() external;

    function withdrawTo(address to) external;

    // function rescueFunds(IERC20 token, uint256 amount) external;

    function isExemptFromEarlyWithdrawFees(address account) external view returns (bool);

    function addEarlyWithdrawFeeExemption(address account, bool exempt) external;
}
