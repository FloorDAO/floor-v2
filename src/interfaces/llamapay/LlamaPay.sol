//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILlamaPay {

    struct Payer {
        uint40 lastPayerUpdate;
        uint216 totalPaidPerSec;
    }

    function streamToStart(bytes32) external returns (uint);

    function payers(address) external returns (Payer memory);

    function balances(address) external returns (uint);

    function token() external returns (IERC20);

    function DECIMALS_DIVISOR() external returns (uint);

    function getStreamId(address from, address to, uint216 amountPerSec) external pure returns (bytes32);

    function createStream(address to, uint216 amountPerSec) external;

    function createStreamWithReason(address to, uint216 amountPerSec, string calldata reason) external;

    function withdrawable(address from, address to, uint216 amountPerSec) external view returns (uint withdrawableAmount, uint lastUpdate, uint owed);

    function withdraw(address from, address to, uint216 amountPerSec) external;

    function cancelStream(address to, uint216 amountPerSec) external;

    function pauseStream(address to, uint216 amountPerSec) external;

    function modifyStream(address oldTo, uint216 oldAmountPerSec, address to, uint216 amountPerSec) external;

    function deposit(uint amount) external;

    function depositAndCreate(uint amountToDeposit, address to, uint216 amountPerSec) external;

    function depositAndCreateWithReason(uint amountToDeposit, address to, uint216 amountPerSec, string calldata reason) external;

    function withdrawPayer(uint amount) external;

    function withdrawPayerAll() external;

    function getPayerBalance(address payerAddress) external view returns (int);
}
