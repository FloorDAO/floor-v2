// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IAction} from '../../../interfaces/actions/Action.sol';
import {IWETH} from '../../../interfaces/tokens/WETH.sol';

/**
 * This action allows us to wrap ETH in the {Treasury} into WETH.
 */
contract WrapEth is IAction {
    /// Mainnet WETH contract
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// The {Treasury} contract that will provide the ERC20 tokens and will be
    /// the recipient of the swapped WETH.
    address public immutable treasury;

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     *
     * @param _treasury Address of the Floor {Treasury} contract
     */
    constructor(address _treasury) {
        treasury = _treasury;
    }

    /**
     * Wraps a fixed amount of ETH into WETH.
     *
     * @return uint The amount of ETH wrapped into WETH by the execution
     */
    function execute(bytes calldata /* _request */) public payable returns (uint) {
        IWETH(WETH).deposit{value: msg.value}();
        IWETH(WETH).transfer(treasury, msg.value);

        // We return just the amount of WETH generated in the swap, which will have
        // already been transferred to the {Treasury}.
        return msg.value;
    }
}
