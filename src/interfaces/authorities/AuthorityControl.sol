// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IAuthorityControl {

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns `true` if `account` has been granted either the GOVERNOR or
     * GUARDIAN `role`.
     */
    function hasAdminRole(address account) external view returns (bool);

}
