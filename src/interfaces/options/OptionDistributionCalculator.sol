// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * Our {OptionExchange} implements an {IOptionDistributionCalculator} contract to
 * provide a method of calculating a user's share and discount allocations based
 * on a seed value.
 */
abstract contract IOptionDistributionCalculator {

    /**
     * Get the share allocation based on the seed.
     */
    function getShare(uint seed) external virtual returns (uint);

    /**
     * Get the discount allocation based on the seed.
     */
    function getDiscount(uint seed) external virtual returns (uint);

}
