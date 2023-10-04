// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {LSSVMPair} from 'lssvm2/LSSVMPair.sol';
import {LSSVMPairETH} from 'lssvm2/LSSVMPairETH.sol';
import {GDACurve} from "lssvm2/bonding-curves/GDACurve.sol";
import {LSSVMPairERC721ETH} from "lssvm2/erc721/LSSVMPairERC721ETH.sol";
import {LSSVMPairFactory, IERC721, IERC1155, ILSSVMPairFactoryLike} from 'lssvm2/LSSVMPairFactory.sol';
import {ILSSVMPairFactoryLike} from "lssvm2/ILSSVMPairFactoryLike.sol";

import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";

import {SudoswapSweeper} from '@floor/sweepers/Sudoswap.sol';

import {ERC721Mock} from "../mocks/erc/ERC721Mock.sol";
import {FloorTest} from '../utilities/Environments.sol';

contract SudoswapSweeperTest is FloorTest, ERC721TokenReceiver {
    address payable constant ASSET_RECIPIENT = payable(address(0xB0B));
    address payable constant SWAP_OUTPUT_RECIPIENT = payable(address(0x6969));

    LSSVMPairFactory internal pairFactory;
    GDACurve internal gdaCurve;

    ERC721Mock internal mock721;
    ERC721Mock internal mock721Alt;
    ERC721Mock internal mock721Fees;

    SudoswapSweeper internal sweeper;

    address payable alice;

    constructor () forkBlock(18_241_740) {}

    function setUp() public {
        // Deploy a mocked ERC721 contract so that we can manipulate
        // the number of tokens available.
        mock721 = new ERC721Mock();
        mock721Alt = new ERC721Mock();
        mock721Fees = new ERC721Mock();

        // Set fees on the ERC721 of 5%
        mock721Fees.setRoyaltyFees(5_000);

        // Register our Sudoswap contract addresses
        address payable PAIR_FACTORY = payable(0xA020d57aB0448Ef74115c112D18a9C231CC86000);
        address GDA_CURVE = 0x1fD5876d4A3860Eb0159055a3b7Cb79fdFFf6B67;

        // Deploy our sweeper contract
        sweeper = new SudoswapSweeper(ASSET_RECIPIENT, PAIR_FACTORY, GDA_CURVE, address(0));

        alice = users[0];
    }

    function test_CanCreateErc721Pool() public {
        // Confirm that the sweeper pool mapping does not currently exist
        assertEq(sweeper.sweeperPools(address(mock721)), address(0));

        // Create a mock 721 sweep with 20 ether allocated to the pool
        _singleCollectionExecute(address(mock721), 20 ether);

        // The mapping should now be set
        assertEq(sweeper.sweeperPools(address(mock721)), 0x42a2C8c73Cab9e0b948b0C96393711B8bCFbF90d);

        // Confirm that the pool is set up as expected
        LSSVMPair pair = LSSVMPair(sweeper.sweeperPools(address(mock721)));
        assertEq(pair.spotPrice(), 0.1 ether, 'Invalid spot price');
        assertEq(pair.delta(), 324959260312975272114441422495994967, 'Invalid delta');
        assertEq(pair.fee(), 0, 'Invalid fee');
        assertEq(uint(pair.pairVariant()), 0, 'Invalid pair variant');
        assertEq(address(pair.bondingCurve()), address(sweeper.gdaCurve()), 'Invalid bonding curve');
        assertEq(address(pair.factory()), address(sweeper.pairFactory()), 'Invalid pair factory');
        assertEq(pair.nft(), address(mock721), 'Invalid NFT address');
        assertEq(uint(pair.poolType()), 0, 'Invalid pool type');
        assertEq(pair.getAssetRecipient(), ASSET_RECIPIENT, 'Invalid asset recipient');
        assertEq(pair.getFeeRecipient(), ASSET_RECIPIENT, 'Invalid fee recipient');

        // Confirm how the alpha / lambda affects a new purchase
        (, uint newSpotPrice, uint newDelta, uint inputAmount, uint protocolFee, uint royaltyAmount) = pair.getBuyNFTQuote(0, 1);
        assertEq(newSpotPrice, 0.105 ether, 'Invalid new spot price');
        assertEq(newDelta, 324959260312975272114441422495994967, 'Invalid new delta');
        assertEq(inputAmount, 0.1005 ether, 'Invalid input amount');
        assertEq(protocolFee, 0.0005 ether, 'Invalid protocol fee');
        assertEq(royaltyAmount, 0, 'Invalid royalty amount');

        // Confirm that the ETH balance deposited is registered
        assertEq(payable(address(pair)).balance, 20 ether, 'Invalid balance');
    }

    function test_CanCreatePoolWithZeroAmount() public {
        _singleCollectionExecute(address(mock721), 0);
    }

    function test_CanFundExistingErc721Pool() public {
        // Create a mock 721 sweep with 20 ether allocated to the pool
        _singleCollectionExecute(address(mock721), 20 ether);

        // Provide an additional 30 ether to the pool
        _singleCollectionExecute(address(mock721), 30 ether);

        // Confirm that the ETH balance deposited is registered
        LSSVMPair pair = LSSVMPair(sweeper.sweeperPools(address(mock721)));
        assertEq(payable(address(pair)).balance, 50 ether, 'Invalid balance');
    }

    function test_CanCreateAndFundMultipleTokenPoolsInSingleTransation() public {
        // Create an initial collection that will already exist in our multicall
        _singleCollectionExecute(address(mock721), 20 ether);

        // Set up our multicall parameters
        address[] memory collections = new address[](3);
        collections[0] = address(mock721);
        collections[1] = address(mock721Alt);
        collections[2] = address(mock721Fees);

        uint[] memory amounts = new uint[](3);
        amounts[0] = 10 ether;
        amounts[1] = 35 ether;
        amounts[2] = 20 ether;

        // Run our multicall to fund one pool and create both a royalty-enabled
        // and non-royalty pool.
        sweeper.execute{value: 65 ether}(collections, amounts, '');
    }

    function test_PoolPriceUpdatesOverTime() public {
        // Create our collection that we will sell into
        _singleCollectionExecute(address(mock721Fees), 20 ether);

        // Define our pair contract
        LSSVMPair pair = LSSVMPair(sweeper.sweeperPools(address(mock721Fees)));

        // sell NFTs to pair
        (,,, uint outputAmount, uint protocolFee, uint royaltyAmount) = pair.getSellNFTQuote(0, 1);
        assertEq(outputAmount, 94525000000000000);
        assertEq(protocolFee, 500000000000000);
        assertEq(royaltyAmount, 4975000000000000);

        // Wait for price change
        skip(6 hours);

        // sell NFTs to pair
        (,,, outputAmount, protocolFee, royaltyAmount) = pair.getSellNFTQuote(0, 1);
        assertEq(outputAmount, 96793600000000000000);
        assertEq(protocolFee, 512000000000000000);
        assertEq(royaltyAmount, 5094400000000000000);

        // Wait for price change
        skip(12 hours);

        // sell NFTs to pair
        // TODO: Why is this same price?
        (,,, outputAmount, protocolFee, royaltyAmount) = pair.getSellNFTQuote(0, 1);
        assertEq(outputAmount, 96793600000000000000);
        assertEq(protocolFee, 512000000000000000);
        assertEq(royaltyAmount, 5094400000000000000);
    }

    function test_CanReceiveEthFromErc721Pool() public {
        // Create our collection that we will sell into
        _singleCollectionExecute(address(mock721), 20 ether);

        // Capture our test user's start balance
        uint startBalance = payable(alice).balance;

        // Mint some ERC721 tokens to our test user
        mock721.mint(alice, 0);
        mock721.mint(alice, 1);
        mock721.mint(alice, 2);

        // Define our pair contract
        LSSVMPair pair = LSSVMPair(sweeper.sweeperPools(address(mock721)));

        // Sell 2 NFTs into the pool as Alice
        vm.startPrank(alice);
        (,,, uint outputAmount,,) = pair.getSellNFTQuote(0, 2);

        // Approve the pair to handle the NFTs
        mock721.setApprovalForAll(address(pair), true);

        // Built a list of NFT IDs that Alice is swapping in
        uint[] memory idList = new uint[](2);
        idList[0] = 0;
        idList[1] = 2;

        // Action our swap, with Alice receiving the tokens
        pair.swapNFTsForToken(idList, outputAmount, alice, false, address(this));
        vm.stopPrank();

        // Verify our results from the swap. Our treasury should now have 2 of the NFTs ..
        assertEq(mock721.ownerOf(0), ASSET_RECIPIENT, 'did not receive NFTs');
        assertEq(mock721.ownerOf(1), alice, 'did not receive NFTs');
        assertEq(mock721.ownerOf(2), ASSET_RECIPIENT, 'did not receive NFTs');

        // .. and Alice should now have the expected amount of ETH
        assertEq(payable(alice).balance - startBalance, outputAmount, 'Did not receive correct ETH');
    }

    function test_CanWithdrawEthFromPool() public {
        // Create our collection pair with 20 ether to start
        _singleCollectionExecute(address(mock721), 20 ether);

        // Define our pair contract
        LSSVMPairETH pair = LSSVMPairETH(sweeper.sweeperPools(address(mock721)));

        // Get our recipient's starting balance
        uint startBalance = ASSET_RECIPIENT.balance;

        // Now we want to remove the ether from the pool
        sweeper.endSweep(sweeper.sweeperPools(address(mock721)));

        // Confirm that the pool now has no ether balance
        assertEq(payable(address(pair)).balance, 0);

        // Confirm that our recipient holds the additional ETH
        assertEq(ASSET_RECIPIENT.balance - startBalance, 20 ether);
    }

    function _singleCollectionExecute(address _collection, uint _amount) internal {
        address[] memory collection = new address[](1);
        collection[0] = _collection;

        uint[] memory amount = new uint[](1);
        amount[0] = _amount;

        sweeper.execute{value: _amount}(collection, amount, '');
    }
}
