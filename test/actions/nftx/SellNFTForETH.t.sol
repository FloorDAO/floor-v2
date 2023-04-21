// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {NFTXSellNftsForEth} from '@floor/actions/nftx/SellNftsForEth.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract NFTXSellNftsForEthTest is FloorTest {
    // ..
    address internal constant RBC_CONTRACT = 0xE63bE4Ed45D32e43Ff9b53AE9930983B0367330a;

    // Set up our Marketplace zap address
    address internal constant MARKETPLACE_ZAP = 0x0fc584529a2AEfA997697FAfAcbA5831faC0c22d;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

    // Store our action contract
    NFTXSellNftsForEth action;

    // Store the treasury address
    address treasury;

    constructor() forkBlock(BLOCK_NUMBER) {}

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    function setUp() public {
        // Set up our Treasury. In this test we will just use an account that
        // we know has the tokens that we need. This test will need to be updated
        // when our {Treasury} contract is completed.
        treasury = 0x15abb66bA754F05cBC0165A64A11cDed1543dE48;

        // Set up a floor migration contract
        action = new NFTXSellNftsForEth(MARKETPLACE_ZAP);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanSellNFT() public {
        // Has vault-valid NFTs at block
        vm.startPrank(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96);

        uint[] memory tokens = new uint[](2);
        tokens[0] = 1;
        tokens[1] = 1870;

        address[] memory path = new address[](2);
        path[0] = 0x0E5F6E67099529557F335be9E2333D90DCE0861b;
        path[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        // Lazy approve all the NFTs
        ERC721(RBC_CONTRACT).setApprovalForAll(address(action), true);

        // Action our trade
        uint amountOut = action.execute(
            abi.encode(
                RBC_CONTRACT, // asset
                uint(269), // vaultId
                tokens, // tokenIds
                uint(13044045363965763), // minEthOut
                path // path
            )
        );

        // Confirm that we received the expected amount of ETH
        assertEq(amountOut, 13175803397945216);

        vm.stopPrank();
    }

    function test_CannotCompleteSellWithInsufficientEthOut(uint minEthOut) public {
        // We assume our fuzz test value is above the amountOut from a successful
        // test sale with the same parameters.
        vm.assume(minEthOut > 13175803397945216);

        // Has vault-valid NFTs at block
        vm.startPrank(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96);

        uint[] memory tokens = new uint[](2);
        tokens[0] = 1;
        tokens[1] = 1870;

        address[] memory path = new address[](2);
        path[0] = 0x0E5F6E67099529557F335be9E2333D90DCE0861b;
        path[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        // Lazy approve all the NFTs
        ERC721(RBC_CONTRACT).setApprovalForAll(address(action), true);

        // Action our trade
        vm.expectRevert('UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        action.execute(
            abi.encode(
                RBC_CONTRACT, // asset
                uint(269), // vaultId
                tokens, // tokenIds
                uint(23044045363965763), // minEthOut
                path // path
            )
        );

        vm.stopPrank();
    }
}
