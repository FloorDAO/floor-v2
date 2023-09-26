// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {NFTXBuyNftsWithEth} from '@floor/actions/nftx/BuyNftsWithEth.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract NFTXBuyNftsWithEthTest is FloorTest {
    // ..
    address internal constant RBC_CONTRACT = 0xE63bE4Ed45D32e43Ff9b53AE9930983B0367330a;

    // Set up our Marketplace zap address
    address internal constant MARKETPLACE_ZAP = 0x0fc584529a2AEfA997697FAfAcbA5831faC0c22d;

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_973_297;

    // Store our action contract
    NFTXBuyNftsWithEth action;

    // Temporary hold to test number of received tokens
    uint receivedTokens;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();
    }

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    function setUp() public {
        // Set up a floor migration contract
        action = new NFTXBuyNftsWithEth(MARKETPLACE_ZAP);
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanBuySpecificTokens(uint specificTokens, uint randomTokens) public {
        vm.assume(specificTokens <= 5);
        vm.assume(randomTokens <= 20);
        vm.assume(randomTokens + specificTokens > 0);

        uint[] memory specificIds = new uint[](specificTokens);
        uint[] memory potentialSpecificIds = new uint[](5);
        potentialSpecificIds[0] = 891;
        potentialSpecificIds[1] = 2776;
        potentialSpecificIds[2] = 5197;
        potentialSpecificIds[3] = 712;
        potentialSpecificIds[4] = 703;

        for (uint i; i < specificTokens; ++i) {
            specificIds[i] = potentialSpecificIds[i];
        }

        address[] memory path = new address[](2);
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        path[1] = 0x0E5F6E67099529557F335be9E2333D90DCE0861b;

        // Action our trade
        uint tokens = action.execute{value: 5 ether}(
            abi.encode(
                uint(269), // vault ID
                specificTokens + randomTokens, // amount of tokens to buy
                specificIds, // specific IDs
                path // path
            )
        );

        // Confirm that we received the expected amount of ETH
        assertEq(tokens, specificTokens + randomTokens);
        assertEq(tokens, receivedTokens);

        // Confirm that we hold the tokens
        for (uint i; i < specificIds.length; ++i) {
            assertEq(ERC721(RBC_CONTRACT).ownerOf(specificIds[i]), address(this));
        }
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint, bytes memory) public virtual returns (bytes4) {
        receivedTokens += 1;
        return this.onERC721Received.selector;
    }

    /**
     * Allows the contract to receive refunded ETH.
     */
    receive() external payable {}

}
