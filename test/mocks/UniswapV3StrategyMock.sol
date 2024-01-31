// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {UniswapV3Strategy} from '@floor/strategies/UniswapV3Strategy.sol';

import {IUniswapV3NonfungiblePositionManager} from '@floor-interfaces/uniswap/IUniswapV3NonfungiblePositionManager.sol';


contract UniswapV3StrategyMock is UniswapV3Strategy {

    function setTokenId(uint24 _tokenId) public {
        tokenId = _tokenId;
    }

}
