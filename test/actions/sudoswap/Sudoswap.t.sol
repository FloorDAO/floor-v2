// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {LSSVMPair} from '@sudoswap/LSSVMPair.sol';

import {SudoswapBuyNftsWithEth} from '@floor/actions/sudoswap/BuyNftsWithEth.sol';
import {SudoswapCreatePair} from '@floor/actions/sudoswap/CreatePair.sol';
import {SudoswapSellNftsForEth} from '@floor/actions/sudoswap/SellNftsForEth.sol';

import {ERC20Mock} from '../../mocks/erc/ERC20Mock.sol';
import {FloorTest} from '../../utilities/Environments.sol';


contract SudoswapTest is FloorTest, IERC721Receiver {

    // Store our action contracts
    SudoswapBuyNftsWithEth internal buyNfts;
    SudoswapCreatePair internal createPair;
    SudoswapSellNftsForEth internal sellNfts;

    // Store our mock ERC20 token
    ERC20Mock mockToken;

    // Store our test NFT
    IERC721 nft = IERC721(0x524cAB2ec69124574082676e6F654a18df49A048);

    // Store some of the deployed bonding curve addresses
    address internal constant LINEAR_BONDING = 0x1268CFc4a818e94A2A3eE72B8507aC9F72fa01C5;

    // Store our test user
    address alice;

    constructor() forkBlock(17_094_248) {
        // Set up our actions
        buyNfts = new SudoswapBuyNftsWithEth();
        createPair = new SudoswapCreatePair(payable(0x6aFF0d25C7801a84241ae1537FC05B79C12c9629));
        sellNfts = new SudoswapSellNftsForEth();

        // Create a mock token we can use for token pairings and provide our user with
        // sufficient, approved balance.
        mockToken = new ERC20Mock();
        mockToken.mint(address(this), 100 ether);
        mockToken.approve(address(createPair), 100 ether);

        // Transfer our NFT tokens into the test contract to work with
        vm.startPrank(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96);
        nft.transferFrom(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, address(this), 1297);
        nft.transferFrom(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, address(this), 11580);
        nft.transferFrom(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96, address(this), 15924);
        vm.stopPrank();

        // Now that we have the NFT tokens in the test contract, we can approve our pair
        // creation contract to use them and also the sales contract to sell them.
        nft.setApprovalForAll(address(createPair), true);
        nft.setApprovalForAll(address(sellNfts), true);

        // Set up a test user
        alice = users[0];
    }

    function test_CanCreateEthPair() public {
        uint vaultAddressUint = createPair.execute{value: 10 ether}(
            abi.encode(
                address(0), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.NFT, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                0, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));
        assertEq(vaultAddress, 0xC0fAB5E289a04B8C3561Ec316D348DcDa66d540C);
    }

    function test_CanCreateTokenPair() public {
        uint vaultAddressUint = createPair.execute(
            abi.encode(
                address(mockToken), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                3 ether, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));
        assertEq(vaultAddress, 0xC0fAB5E289a04B8C3561Ec316D348DcDa66d540C);
    }

    function test_CannotSendUnsupportedPairType() public {
        vm.expectRevert('Unknown pool type');
        createPair.execute(
            abi.encode(
                address(mockToken), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TOKEN, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                30 ether, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );
    }

    function test_CanBuyNftsWithEth() public {
        uint vaultAddressUint = createPair.execute{value: 10 ether}(
            abi.encode(
                address(0), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.NFT, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                0, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));

        // Get a quote from the pair to confirm the view function is accurate for 2 NFTs
        (,,,uint estimate,) = LSSVMPair(vaultAddress).getBuyNFTQuote(2);
        assertEq(estimate, 2.002 ether);

        // Capture the starting balance of our test user that will be making the sale,
        // and making the buy.
        uint buyerStartBalance = address(alice).balance;
        uint sellerStartBalance = address(this).balance;

        // Buy 2 NFTs as our buyer (alice)
        vm.prank(alice);
        uint spent = buyNfts.execute{value: 10 ether}(
            abi.encode(
                vaultAddress, // address pair;
                2, // uint numNFTs;
                10 ether, // uint maxExpectedTokenInput;
                address(this) // address nftRecipient;
            )
        );

        // Confirm the amount that was spent in the return value
        assertEq(spent, 2.002 ether);

        // Confirm that our involved accounts end with expected balances
        assertEq(address(alice).balance, buyerStartBalance - spent);
        assertEq(address(this).balance, sellerStartBalance + 2 ether);

        // Confirm that our expected recipient now owns 2 of the NFTs and the pair
        // address still owns the remaining token.
        assertEq(nft.ownerOf(1297), vaultAddress);
        assertEq(nft.ownerOf(11580), address(this));
        assertEq(nft.ownerOf(15924), address(this));
    }

    function test_CannotBuyMoreTokensThanAvailableOrZero(uint nftAmount) public {
        vm.assume(nftAmount == 0 || nftAmount == 4);

        uint vaultAddressUint = createPair.execute{value: 10 ether}(
            abi.encode(
                address(0), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.NFT, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                0, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));

        // Buy 2 NFTs as our buyer (alice)
        vm.expectRevert('Ask for > 0 and <= balanceOf NFTs');
        vm.prank(alice);
        buyNfts.execute{value: 10 ether}(
            abi.encode(
                vaultAddress, // address pair;
                nftAmount, // uint numNFTs;
                10 ether, // uint maxExpectedTokenInput;
                address(this) // address nftRecipient;
            )
        );
    }

    function test_CannotBuyWithInsufficientBalance() public {
        uint vaultAddressUint = createPair.execute{value: 10 ether}(
            abi.encode(
                address(0), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.NFT, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                0, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));

        // Buy 2 NFTs as our buyer (alice)
        vm.expectRevert('In too many tokens');
        vm.prank(alice);
        buyNfts.execute{value: 2 ether}(
            abi.encode(
                vaultAddress, // address pair;
                2, // uint numNFTs;
                2 ether, // uint maxExpectedTokenInput;
                address(this) // address nftRecipient;
            )
        );
    }

    function test_CanBuyNftsWithTokens() public {
        // Create a pairing with 3 ERC721 and 3 ERC20
        uint vaultAddressUint = createPair.execute(
            abi.encode(
                address(mockToken), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                3 ether, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));
        assertEq(vaultAddress, 0xC0fAB5E289a04B8C3561Ec316D348DcDa66d540C);

        // Get a quote from the pair to confirm the view function is accurate for 2 NFTs
        (,,,uint estimate,) = LSSVMPair(vaultAddress).getBuyNFTQuote(2);
        assertEq(estimate, 2.002 ether);

        // Mint and approve our tokens as the buyer (alice)
        mockToken.mint(alice, 100 ether);
        vm.prank(alice);
        mockToken.approve(address(buyNfts), 100 ether);

        // Capture the starting balance of our test user that will be making the sale,
        // and making the buy.
        uint buyerStartBalance = mockToken.balanceOf(alice);
        uint sellerStartBalance = mockToken.balanceOf(address(this));

        // Buy 2 NFTs as our buyer (alice)
        vm.prank(alice);
        uint spent = buyNfts.execute(
            abi.encode(
                vaultAddress, // address pair;
                2, // uint numNFTs;
                10 ether, // uint maxExpectedTokenInput;
                address(this) // address nftRecipient;
            )
        );

        // Confirm the amount that was spent in the return value
        assertEq(spent, 2.002 ether);

        // Confirm that our involved accounts end with expected balances
        assertEq(mockToken.balanceOf(alice), buyerStartBalance - spent);
        assertEq(mockToken.balanceOf(address(this)), sellerStartBalance);

        // In this case, the creator will have not yet received any tokens as it needs
        // to be claimed from the contract.

        // Confirm that our expected recipient now owns 2 of the NFTs and the pair
        // address still owns the remaining token.
        assertEq(nft.ownerOf(1297), vaultAddress);
        assertEq(nft.ownerOf(11580), address(this));
        assertEq(nft.ownerOf(15924), address(this));
    }

    function test_CannotBuyMoreThanAvailableOrZeroWithTokens(uint nftAmount) public {
        vm.assume(nftAmount == 0 || nftAmount == 4);

        // Create a pairing with 3 ERC721 and 3 ERC20
        uint vaultAddressUint = createPair.execute(
            abi.encode(
                address(mockToken), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                3 ether, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));

        // Mint and approve our tokens as the buyer (alice)
        mockToken.mint(alice, 100 ether);
        vm.prank(alice);
        mockToken.approve(address(buyNfts), 100 ether);

        // Buy 2 NFTs as our buyer (alice)
        vm.expectRevert('Ask for > 0 and <= balanceOf NFTs');
        vm.prank(alice);
        buyNfts.execute(
            abi.encode(
                vaultAddress, // address pair;
                nftAmount, // uint numNFTs;
                10 ether, // uint maxExpectedTokenInput;
                address(this) // address nftRecipient;
            )
        );
    }

    function test_CannotBuyWithInsufficientTokenBalanceWithTokens() public {
        // Create a pairing with 3 ERC721 and 3 ERC20
        uint vaultAddressUint = createPair.execute(
            abi.encode(
                address(mockToken), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                3 ether, // uint initialTokenBalance,
                _initialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));

        // Mint and approve our tokens as the buyer (alice)
        mockToken.mint(alice, 100 ether);
        vm.prank(alice);
        mockToken.approve(address(buyNfts), 100 ether);

        // Buy 2 NFTs as our buyer (alice)
        vm.expectRevert('In too many tokens');
        vm.prank(alice);
        buyNfts.execute(
            abi.encode(
                vaultAddress, // address pair;
                2, // uint numNFTs;
                0.05 ether, // uint maxExpectedTokenInput;
                address(this) // address nftRecipient;
            )
        );
    }

    function test_CanSellNftsForEth() public {
        // Create a pairing with 2 ERC721 with 2 ETH
        uint vaultAddressUint = createPair.execute{value: 2 ether}(
            abi.encode(
                address(0), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                0, // uint initialTokenBalance,
                _initialPartialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));
        assertEq(vaultAddress, 0xC0fAB5E289a04B8C3561Ec316D348DcDa66d540C);

        // Get a quote from the pair to confirm the view function is accurate for 1 NFT
        (,,,uint estimate,) = LSSVMPair(vaultAddress).getSellNFTQuote(1);
        assertEq(estimate, 0.999 ether);

        // Transfer our token to Alice so that she can make the purchase
        nft.transferFrom(address(this), alice, 15924);
        vm.prank(alice);
        nft.setApprovalForAll(address(sellNfts), true);

        // Capture the starting balance of our test user that will be making the sale,
        // and making the buy.
        uint sellerStartBalance = address(alice).balance;

        // Sell 1 NFT for any amount (should give estimated value)
        vm.startPrank(alice);
        uint received = sellNfts.execute(
            abi.encode(
                vaultAddress, // address pair;
                _nftIdForSale(), // uint[] nftIds;
                0 // uint minExpectedTokenOutput;
            )
        );
        vm.stopPrank();

        // Confirm that we received what we were estimated
        assertEq(received, estimate);

        // Confirm that the pairing now holds the NFT token that was sold
        assertEq(nft.ownerOf(15924), vaultAddress);

        // Confirm that our involved accounts end with expected balances
        assertEq(address(alice).balance, sellerStartBalance + received);
    }

    function test_CannotSellNftsForEthWithInsufficientReturns() public {
        // Create a pairing with 2 ERC721 with 2 ETH
        uint vaultAddressUint = createPair.execute{value: 2 ether}(
            abi.encode(
                address(0), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                0, // uint initialTokenBalance,
                _initialPartialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));
        assertEq(vaultAddress, 0xC0fAB5E289a04B8C3561Ec316D348DcDa66d540C);

        // Get a quote from the pair to confirm the view function is accurate for 1 NFT
        (,,,uint estimate,) = LSSVMPair(vaultAddress).getSellNFTQuote(1);
        assertEq(estimate, 0.999 ether);

        // Try and sell our NFT for above our estimate, expecting a revert
        vm.expectRevert('Out too little tokens');
        sellNfts.execute(
            abi.encode(
                vaultAddress, // address pair;
                _nftIdForSale(), // uint[] nftIds;
                estimate + 1 // uint minExpectedTokenOutput;
            )
        );
    }

    function test_CanSellNftsForTokens() public {
        // Create a pairing with 2 ERC721 and 2 ERC20
        uint vaultAddressUint = createPair.execute(
            abi.encode(
                address(mockToken), // address token,
                address(nft), // address nft,
                LINEAR_BONDING, // address bondingCurve,
                LSSVMPair.PoolType.TRADE, // LSSVMPair.PoolType poolType,
                0, // uint128 delta,
                0, // uint96 fee,
                1 ether, // uint128 spotPrice,
                2 ether, // uint initialTokenBalance,
                _initialPartialNftIds() // uint[] memory initialNftIds
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));
        assertEq(vaultAddress, 0xC0fAB5E289a04B8C3561Ec316D348DcDa66d540C);

        // Get a quote from the pair to confirm the view function is accurate for 1 NFT
        (,,,uint estimate,) = LSSVMPair(vaultAddress).getSellNFTQuote(1);
        assertEq(estimate, 0.999 ether);

        // Transfer our token to Alice so that she can make the purchase
        nft.transferFrom(address(this), alice, 15924);
        vm.prank(alice);
        nft.setApprovalForAll(address(sellNfts), true);

        // Capture the starting balance of our test user that will be making the sale,
        // and making the buy.
        uint sellerStartBalance = mockToken.balanceOf(alice);

        // Sell 1 NFT for any amount (should give estimated value)
        vm.startPrank(alice);
        uint received = sellNfts.execute(
            abi.encode(
                vaultAddress, // address pair;
                _nftIdForSale(), // uint[] nftIds;
                0.9 ether // uint minExpectedTokenOutput;
            )
        );
        vm.stopPrank();

        // Confirm that we received what we were estimated
        assertEq(received, estimate);

        // Confirm that the pairing now holds the NFT token that was sold
        assertEq(nft.ownerOf(15924), vaultAddress);

        // Confirm that our involved accounts end with expected balances
        assertEq(mockToken.balanceOf(alice), sellerStartBalance + received);
    }

    function _initialNftIds() internal pure returns (uint[] memory initialNftIds) {
        initialNftIds = new uint[](3);
        initialNftIds[0] = 1297;
        initialNftIds[1] = 11580;
        initialNftIds[2] = 15924;
    }

    function _initialPartialNftIds() internal pure returns (uint[] memory initialNftIds) {
        initialNftIds = new uint[](2);
        initialNftIds[0] = 1297;
        initialNftIds[1] = 11580;
    }

    function _nftIdForSale() internal pure returns (uint[] memory nftIds) {
        nftIds = new uint[](1);
        nftIds[0] = 15924;
    }

    /**
     * Implementing `onERC721Received` so this contract can receive custody of erc721 tokens.
     *
     * @dev Note that the operator is recorded as the owner of the deposited NFT.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    receive() external payable {
        //
    }

}
