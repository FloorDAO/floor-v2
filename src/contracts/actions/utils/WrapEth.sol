// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Action} from '@floor/actions/Action.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * This action allows us to wrap ETH in the {Treasury} into WETH.
 */
contract WrapEth is Action {
    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * Wraps a fixed amount of ETH into WETH.
     *
     * @return uint The amount of ETH wrapped into WETH by the execution
     */
    function execute(bytes calldata /* _request */ ) public payable override whenNotPaused returns (uint) {
        IWETH(WETH).deposit{value: msg.value}();
        IWETH(WETH).transfer(msg.sender, msg.value);

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury}.
        return msg.value;
    }
}
