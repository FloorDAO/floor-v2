// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SafeMathInt
 * @dev Math operations with safety checks that revert on error
 * @dev SafeMath adapted for int256
 * Based on code of  https://github.com/RequestNetwork/requestNetwork/blob/master/packages/requestNetworkSmartContracts/contracts/base/math/SafeMathInt.sol
 */
library SafeMathInt {
    function mul(int a, int b) internal pure returns (int) {
        // Prevent overflow when multiplying INT256_MIN with -1
        // https://github.com/RequestNetwork/requestNetwork/issues/43
        require(!(a == -2 ** 255 && b == -1) && !(b == -2 ** 255 && a == -1));

        int c = a * b;
        require((b == 0) || (c / b == a));
        return c;
    }

    function div(int a, int b) internal pure returns (int) {
        // Prevent overflow when dividing INT256_MIN by -1
        // https://github.com/RequestNetwork/requestNetwork/issues/43
        require(!(a == -2 ** 255 && b == -1) && (b > 0));

        return a / b;
    }

    function sub(int a, int b) internal pure returns (int) {
        require((b >= 0 && a - b <= a) || (b < 0 && a - b > a));

        return a - b;
    }

    function add(int a, int b) internal pure returns (int) {
        int c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    function toUint256Safe(int a) internal pure returns (uint) {
        require(a >= 0);
        return uint(a);
    }
}
