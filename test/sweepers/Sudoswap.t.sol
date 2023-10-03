// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {LSSVMPair} from 'lssvm2/LSSVMPair.sol';
import {GDACurve} from "lssvm2/bonding-curves/GDACurve.sol";
import {LSSVMPairERC721ETH} from "lssvm2/erc721/LSSVMPairERC721ETH.sol";
import {LSSVMPairFactory, IERC721, IERC1155, ILSSVMPairFactoryLike} from 'lssvm2/LSSVMPairFactory.sol';

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

    SudoswapSweeper internal sweeper;

    constructor () forkBlock(18_241_740) {}

    function setUp() public {
        // Deploy a mocked ERC721 contract so that we can manipulate
        // the number of tokens available.
        testERC721 = new TestERC721();

        // Register our Sudoswap contract addresses
        address payable PAIR_FACTORY = 0xA020d57aB0448Ef74115c112D18a9C231CC86000;
        address GDA_CURVE = 0x1fD5876d4A3860Eb0159055a3b7Cb79fdFFf6B67;

        // Deploy our sweeper contract
        sweeper = new SudoswapSweeper(ASSET_RECIPIENT, PAIR_FACTORY, GDA_CURVE);

        // Approve our sweeper contract to be used

    }

    function test_CanCreateErc721Pool() public {}

    function test_CanFundExistingErc721Pool() public {}

    function test_CanCreateAndFundMultipleTokenPoolsInSingleTransation() public {}

    function test_CanReceiveEthFromErc721Pool() public {}

    function test_CanWithdrawErc721TokensFromPool() public {}

    function test_CanSetAssetRecipient() public {}
    function test_CanSetInitialSpotPrice() public {}

    function test_buy_erc721_eth(uint256 alpha, uint256 lambda, uint256 waitTime, uint256 sellNftAmount) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 0, type(uint40).max);
        waitTime = bound(waitTime, 1, 1 weeks);
        sellNftAmount = bound(sellNftAmount, 1, 10);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ETH(
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0)
        );

        // wait for price change
        skip(waitTime);

        // sell NFTs to pair
        (,,, uint256 outputAmount, uint256 protocolFee, uint256 royaltyAmount) = pair.getSellNFTQuote(1, sellNftAmount);
        deal(address(pair), outputAmount + protocolFee + royaltyAmount); // give pair enough ETH to buy the NFTs
        uint256[] memory idList = _getIdList(1, sellNftAmount);
        _mintERC721s(idList, address(this));
        testERC721.setApprovalForAll(address(pair), true);
        pair.swapNFTsForToken(idList, outputAmount, SWAP_OUTPUT_RECIPIENT, false, address(this));

        // verify results
        assertEq(testERC721.balanceOf(ASSET_RECIPIENT), sellNftAmount, "didn't receive NFTs");
        assertEq(SWAP_OUTPUT_RECIPIENT.balance, outputAmount, "didn't receive tokens");
    }

    function test_buy_erc721_erc20(uint256 alpha, uint256 lambda, uint256 waitTime, uint256 sellNftAmount) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 0, type(uint40).max);
        waitTime = bound(waitTime, 1, 1 weeks);
        sellNftAmount = bound(sellNftAmount, 1, 10);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ERC20(
            testERC20,
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0),
            0
        );

        // wait for price change
        skip(waitTime);

        // sell NFTs to pair
        (,,, uint256 outputAmount, uint256 protocolFee, uint256 royaltyAmount) = pair.getSellNFTQuote(1, sellNftAmount);
        deal(address(testERC20), address(pair), outputAmount + protocolFee + royaltyAmount); // give pair enough tokens to buy the NFTs
        uint256[] memory idList = _getIdList(1, sellNftAmount);
        _mintERC721s(idList, address(this));
        testERC721.setApprovalForAll(address(pair), true);
        pair.swapNFTsForToken(idList, outputAmount, SWAP_OUTPUT_RECIPIENT, false, address(this));

        // verify results
        assertEq(testERC721.balanceOf(ASSET_RECIPIENT), sellNftAmount, "didn't receive NFTs");
        assertEq(testERC20.balanceOf(SWAP_OUTPUT_RECIPIENT), outputAmount, "didn't receive tokens");
    }

    function test_deposit_erc721_eth(uint256 alpha, uint256 lambda, uint256 waitTime, uint256 depositAmount) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        waitTime = bound(waitTime, 1, 1 weeks);
        depositAmount = bound(depositAmount, 0.1 ether, 10 ether);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ETH(
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0)
        );
        (,,, uint256 initialOutputAmount,,) = pair.getSellNFTQuote(1, 1);

        // wait for price change
        skip(waitTime);

        (,,, uint256 outputAmount,,) = pair.getSellNFTQuote(1, 1);
        assertTrue(outputAmount != initialOutputAmount, "pricing didn't change over time");

        // deposit tokens
        deal(address(this), depositAmount);
        autoGda.depositETHToPair{value: depositAmount}(pair);

        // verify results
        (,,, outputAmount,,) = pair.getSellNFTQuote(1, 1);
        assertEq(address(pair).balance, depositAmount, "pair didn't get tokens");
        assertEq(outputAmount, initialOutputAmount, "pricing didn't reset after deposit");
    }

    function test_deposit_erc721_erc20(uint256 alpha, uint256 lambda, uint256 waitTime, uint256 depositAmount) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        waitTime = bound(waitTime, 1, 1 weeks);
        depositAmount = bound(depositAmount, 0.1 ether, 10 ether);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ERC20(
            testERC20,
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0),
            0
        );
        (,,, uint256 initialOutputAmount,,) = pair.getSellNFTQuote(1, 1);

        // wait for price change
        skip(waitTime);

        (,,, uint256 outputAmount,,) = pair.getSellNFTQuote(1, 1);
        assertTrue(outputAmount != initialOutputAmount, "pricing didn't change over time");

        // deposit tokens
        deal(address(testERC20), address(this), depositAmount);
        autoGda.depositERC20ToPair(pair, depositAmount);

        // verify results
        (,,, outputAmount,,) = pair.getSellNFTQuote(1, 1);
        assertEq(testERC20.balanceOf(address(pair)), depositAmount, "pair didn't get tokens");
        assertEq(outputAmount, initialOutputAmount, "pricing didn't reset after deposit");
    }

    function test_deposit_erc1155_eth(
        uint256 alpha,
        uint256 lambda,
        uint256 waitTime,
        uint256 depositAmount,
        uint256 nftId
    ) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        waitTime = bound(waitTime, 1, 1 weeks);
        depositAmount = bound(depositAmount, 0.1 ether, 10 ether);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC1155ETH(
            IERC1155(address(testERC1155)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            nftId
        );
        (,,, uint256 initialOutputAmount,,) = pair.getSellNFTQuote(nftId, 1);

        // wait for price change
        skip(waitTime);

        (,,, uint256 outputAmount,,) = pair.getSellNFTQuote(nftId, 1);
        assertTrue(outputAmount != initialOutputAmount, "pricing didn't change over time");

        // deposit tokens
        deal(address(this), depositAmount);
        autoGda.depositETHToPair{value: depositAmount}(pair);

        // verify results
        (,,, outputAmount,,) = pair.getSellNFTQuote(nftId, 1);
        assertEq(address(pair).balance, depositAmount, "pair didn't get tokens");
        assertEq(outputAmount, initialOutputAmount, "pricing didn't reset after deposit");
    }

    function test_deposit_erc1155_erc20(
        uint256 alpha,
        uint256 lambda,
        uint256 waitTime,
        uint256 depositAmount,
        uint256 nftId
    ) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        waitTime = bound(waitTime, 1, 1 weeks);
        depositAmount = bound(depositAmount, 0.1 ether, 10 ether);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC1155ERC20(
            testERC20,
            IERC1155(address(testERC1155)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            nftId,
            0
        );
        (,,, uint256 initialOutputAmount,,) = pair.getSellNFTQuote(nftId, 1);

        // wait for price change
        skip(waitTime);

        (,,, uint256 outputAmount,,) = pair.getSellNFTQuote(nftId, 1);
        assertTrue(outputAmount != initialOutputAmount, "pricing didn't change over time");

        // deposit tokens
        deal(address(testERC20), address(this), depositAmount);
        autoGda.depositERC20ToPair(pair, depositAmount);

        // verify results
        (,,, outputAmount,,) = pair.getSellNFTQuote(nftId, 1);
        assertEq(testERC20.balanceOf(address(pair)), depositAmount, "pair didn't get tokens");
        assertEq(outputAmount, initialOutputAmount, "pricing didn't reset after deposit");
    }

    function test_withdrawETH(uint256 alpha, uint256 lambda, uint256 depositAmount, uint256 withdrawAmount) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);

        // deploy GDA pair via AutoGDA
        deal(address(this), depositAmount);
        LSSVMPair pair = autoGda.deployGDAPairERC721ETH{value: depositAmount}(
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0)
        );

        // withdraw tokens
        vm.prank(ASSET_RECIPIENT);
        autoGda.withdrawETH(pair, withdrawAmount, payable(address(this)));

        // verify
        assertEq(address(this).balance, withdrawAmount, "didn't withdraw tokens");
    }

    function test_withdrawERC20(uint256 alpha, uint256 lambda, uint256 depositAmount, uint256 withdrawAmount) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);

        // deploy GDA pair via AutoGDA
        deal(address(testERC20), address(this), depositAmount);
        LSSVMPair pair = autoGda.deployGDAPairERC721ERC20(
            testERC20,
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0),
            depositAmount
        );

        // withdraw tokens
        vm.prank(ASSET_RECIPIENT);
        autoGda.withdrawERC20(pair, testERC20, withdrawAmount, address(this));

        // verify
        assertEq(testERC20.balanceOf(address(this)), withdrawAmount, "didn't withdraw tokens");
    }

    function test_setAssetRecipient(uint256 alpha, uint256 lambda, address payable newValue) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        vm.assume(newValue != address(0));

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ETH(
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0)
        );

        // set asset recipient
        vm.prank(ASSET_RECIPIENT);
        autoGda.setAssetRecipient(pair, newValue);

        // verify result
        assertEq(pair.getAssetRecipient(), newValue, "didn't set new value");
    }

    function test_setMinDeposit(uint256 alpha, uint256 lambda, uint128 newValue) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ETH(
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0)
        );

        // set asset recipient
        vm.prank(ASSET_RECIPIENT);
        autoGda.setMinDeposit(pair, newValue);

        // verify result
        (uint128 minDeposit,) = autoGda.pairInfos(pair);
        assertEq(minDeposit, newValue, "didn't set new value");
    }

    function test_setInitialSpotPrice(uint256 alpha, uint256 lambda, uint128 newValue) public {
        alpha = bound(alpha, 1e9 + 1, 2e9);
        lambda = bound(lambda, 1e9, type(uint40).max);
        vm.assume(newValue > 1 gwei);

        // deploy GDA pair via AutoGDA
        LSSVMPair pair = autoGda.deployGDAPairERC721ETH(
            IERC721(address(testERC721)),
            ASSET_RECIPIENT,
            0.1 ether,
            0.05 ether,
            _getAlphaAndLambda(alpha, lambda),
            address(0)
        );

        // set asset recipient
        vm.prank(ASSET_RECIPIENT);
        autoGda.setInitialSpotPrice(pair, newValue);

        // verify result
        (, uint128 initialSpotPrice) = autoGda.pairInfos(pair);
        assertEq(initialSpotPrice, newValue, "didn't set new value");
    }

    receive() external payable {}

    function _getIdList(uint256 startId, uint256 amount) internal pure returns (uint256[] memory idList) {
        idList = new uint256[](amount);
        for (uint256 i = startId; i < startId + amount; i++) {
            idList[i - startId] = i;
        }
    }

    function _mintERC721s(uint256[] memory idList, address recipient) internal {
        for (uint256 i; i < idList.length; i++) {
            testERC721.safeMint(recipient, idList[i]);
        }
    }

    function _getAlphaAndLambda(uint256 alpha, uint256 lambda) internal pure returns (uint80 alphaAndLambda) {
        return uint80((alpha << 40) + lambda);
    }
}
