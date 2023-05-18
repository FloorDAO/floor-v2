// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {NftStaking} from '@floor/staking/NftStaking.sol';
import {NftStakingLocker} from '@floor/staking/strategies/NftStakingLocker.sol';
import {NftStakingBoostCalculator} from '@floor/staking/calculators/NftStakingBoostCalculator.sol';
import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NftStakingLockerTest is FloorTest {
    address constant LOW_VALUE_NFT = 0x524cAB2ec69124574082676e6F654a18df49A048;
    address constant HIGH_VALUE_NFT = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    address constant ERC1155_NFT = 0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313;

    address constant LOW_HOLDER_1 = 0x488C636D0a928aeCE719519FBe0cf171B442aBd8;
    address constant LOW_HOLDER_2 = 0x8c0d2B62F133Db265EC8554282eE60EcA0Fd5a9E;
    address constant LOW_HOLDER_3 = 0xA52899A1A8195c3Eef30E0b08658705250E154aE;
    address constant HIGH_HOLDER_1 = 0xa523dA93344dD163C32a8cD9A31459eAD1d86B0A;
    address constant ERC1155_HOLDER = 0xB45470a9688ec3bdBB572B27c305E8c45E014e75;

    // Test users
    address alice;

    uint16 constant VOTE_DISCOUNT = 4000; // 40%

    // Internal contract references
    EpochManager epochManager;
    NftStaking staking;
    NftStakingLocker nftStakingStrategy;
    UniswapV3PricingExecutor pricingExecutor;

    constructor() forkBlock(16_692_005) {
        // Map our test user(s)
        alice = users[0];

        // Set up our pricing executor that is required for boost power calculations
        pricingExecutor = new UniswapV3PricingExecutor(
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0xf59257E961883636290411c11ec5Ae622d19455e
        );

        // Our ERC1155 contract has insufficient liquidity in Uniswap, so we need to
        // mock the response for this.
        vm.mockCall(
            address(pricingExecutor),
            abi.encodeWithSelector(UniswapV3PricingExecutor.getFloorPrice.selector, 0xE97e496E8494232ee128c1a8cAe0b2B7936f3CaA),
            abi.encode(136)
        );

        vm.mockCall(
            address(pricingExecutor),
            abi.encodeWithSelector(UniswapV3PricingExecutor.getLatestFloorPrice.selector, 0xE97e496E8494232ee128c1a8cAe0b2B7936f3CaA),
            abi.encode(136)
        );

        // Set up our epoch manager so that our staking contract has visibility of
        // epoch transitions.
        epochManager = new EpochManager();

        // Set up our staking contract
        staking = new NftStaking(address(pricingExecutor), VOTE_DISCOUNT);

        // Set up our staking strategy
        nftStakingStrategy = new NftStakingLocker(address(staking));

        // Assign the NFT staking strategy to our staking contract
        staking.setStakingStrategy(address(nftStakingStrategy));

        // Add our underlying token mappings (we don't need the xToken)
        nftStakingStrategy.setUnderlyingToken(LOW_VALUE_NFT, 0xB603B3fc4B5aD885e26298b7862Bb6074dff32A9, address(0));
        nftStakingStrategy.setUnderlyingToken(HIGH_VALUE_NFT, 0x269616D549D7e8Eaa82DFb17028d0B212D11232A, address(0));
        nftStakingStrategy.setUnderlyingToken(ERC1155_NFT, 0xE97e496E8494232ee128c1a8cAe0b2B7936f3CaA, address(0));

        // Set our sweep modifier
        staking.setSweepModifier(4e9);

        // Set our default boost calculator
        staking.setBoostCalculator(address(new NftStakingBoostCalculator()));

        // Set our epoch manager contract
        staking.setEpochManager(address(epochManager));

        // Label some addresses for nice debugging
        vm.label(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, 'NFTX Staking Zap');
        vm.label(0x2374a32ab7b4f7BE058A69EA99cb214BFF4868d3, 'NFTX Unstaking Zap');
        vm.label(0xB603B3fc4B5aD885e26298b7862Bb6074dff32A9, 'xLIL');
        vm.label(0x269616D549D7e8Eaa82DFb17028d0B212D11232A, 'xPUNK');

        vm.label(0x8c0d2B62F133Db265EC8554282eE60EcA0Fd5a9E, 'Low Holder 2');
    }

    function test_CanGetVoteBoost() external {
        uint[] memory lowTokens1 = new uint[](5);
        lowTokens1[0] = 16543;
        lowTokens1[1] = 1672;
        lowTokens1[2] = 4774;
        lowTokens1[3] = 4818;
        lowTokens1[4] = 5587;

        uint[] memory lowTokens2 = new uint[](2);
        lowTokens2[0] = 242;
        lowTokens2[1] = 5710;

        uint[] memory lowTokens3 = new uint[](8);
        lowTokens3[0] = 11223;
        lowTokens3[1] = 11202;
        lowTokens3[2] = 11935;
        lowTokens3[3] = 12488;
        lowTokens3[4] = 17445;
        lowTokens3[5] = 19134;
        lowTokens3[6] = 20386;
        lowTokens3[7] = 20315;

        uint[] memory highTokens1 = new uint[](1);
        highTokens1[0] = 6827;

        address approvalAddress = staking.nftStakingStrategy().approvalAddress();

        // User 1 stakes 5 NFT for 104 epochs
        vm.startPrank(LOW_HOLDER_1);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(approvalAddress, true);
        staking.stake(LOW_VALUE_NFT, lowTokens1, _singleAmountArray(lowTokens1.length), 6, false);
        vm.stopPrank();

        // User 2 stakes 2 NFT for 52 epochs
        vm.startPrank(LOW_HOLDER_2);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(approvalAddress, true);
        staking.stake(LOW_VALUE_NFT, lowTokens2, _singleAmountArray(lowTokens2.length), 4, false);
        vm.stopPrank();

        // User 3 stakes 8 NFT for 26 epochs
        vm.startPrank(LOW_HOLDER_3);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(approvalAddress, true);
        staking.stake(LOW_VALUE_NFT, lowTokens3, _singleAmountArray(lowTokens3.length), 3, false);
        vm.stopPrank();

        assertEq(staking.collectionBoost(LOW_VALUE_NFT), 1610730439);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1000000000);

        // User 4 stakes 1 high value NFT for 104 epochs
        vm.startPrank(HIGH_HOLDER_1);
        (bool success,) = address(HIGH_VALUE_NFT).call(
            abi.encodeWithSignature('offerPunkForSaleToAddress(uint256,uint256,address)', highTokens1[0], 0, approvalAddress)
        );
        require(success, 'Failed to offer PUNK');
        staking.stake(HIGH_VALUE_NFT, highTokens1, _singleAmountArray(highTokens1.length), 6, false);
        vm.stopPrank();

        assertEq(staking.collectionBoost(LOW_VALUE_NFT), 1610730439);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1106073976);

        // Skip forward 26 epochs
        epochManager.setCurrentEpoch(epochManager.currentEpoch() + 26);

        // Get the total sweep power against gauge 1
        assertEq(staking.collectionBoost(LOW_VALUE_NFT), 1150729596);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1071691143);

        // Skip forward to our penultimate epoch
        epochManager.setCurrentEpoch(epochManager.currentEpoch() + 104 - 26 - 1);

        // Get the total sweep power against gauge 1
        assertEq(staking.collectionBoost(LOW_VALUE_NFT), 1000000000);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1000000000);
    }

    function test_CanStake1155() external {
        uint[] memory tokenIds = new uint[](5);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        tokenIds[3] = 4;
        tokenIds[4] = 5;

        uint[] memory tokenAmounts = new uint[](5);
        tokenAmounts[0] = 1;
        tokenAmounts[1] = 1;
        tokenAmounts[2] = 1;
        tokenAmounts[3] = 1;
        tokenAmounts[4] = 1;

        address approvalAddress = staking.nftStakingStrategy().approvalAddress();

        vm.startPrank(ERC1155_HOLDER);
        IERC1155(ERC1155_NFT).setApprovalForAll(approvalAddress, true);
        staking.stake(ERC1155_NFT, tokenIds, tokenAmounts, 6, true);
        vm.stopPrank();

        assertEq(staking.collectionBoost(ERC1155_NFT), 1076331713);

        // Skip forward 26 epochs
        epochManager.setCurrentEpoch(epochManager.currentEpoch() + 26);

        // Get the total sweep power against gauge 1
        assertEq(staking.collectionBoost(ERC1155_NFT), 1021095667);

        // Skip forward to our penultimate epoch
        epochManager.setCurrentEpoch(epochManager.currentEpoch() + 104 - 26 - 1);

        // Get the total sweep power against gauge 1
        assertEq(staking.collectionBoost(ERC1155_NFT), 1000000000);
    }

    function test_CannotStake1155WithIncorrectParameters() external {
        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = 1;

        uint[] memory tokenAmounts = new uint[](1);
        tokenAmounts[0] = 1;

        address approvalAddress = staking.nftStakingStrategy().approvalAddress();

        vm.startPrank(ERC1155_HOLDER);
        IERC1155(ERC1155_NFT).setApprovalForAll(approvalAddress, true);

        vm.expectRevert();
        staking.stake(ERC1155_NFT, tokenIds, tokenAmounts, 6, false);
        vm.stopPrank();
    }

    function test_CannotStakeUnownedNft() external {
        uint[] memory tokens = new uint[](1);
        tokens[0] = 1;

        vm.expectRevert();
        staking.stake(ERC1155_NFT, tokens, _singleAmountArray(tokens.length), 6, false);
    }

    function test_CannotStakeInvalidCollectionNft() external {
        uint[] memory tokens = new uint[](1);
        tokens[0] = 992;

        vm.startPrank(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96);
        IERC721(0xE63bE4Ed45D32e43Ff9b53AE9930983B0367330a).setApprovalForAll(address(staking), true);

        vm.expectRevert('Unmapped collection');
        staking.stake(0xE63bE4Ed45D32e43Ff9b53AE9930983B0367330a, tokens, _singleAmountArray(tokens.length), 6, false);

        vm.stopPrank();
    }

    function test_CanUnstake() external {
        uint[] memory tokens = new uint[](2);
        tokens[0] = 242;
        tokens[1] = 5710;

        address approvalAddress = staking.nftStakingStrategy().approvalAddress();

        vm.startPrank(LOW_HOLDER_2);
        // Stake 2 tokens
        IERC721(LOW_VALUE_NFT).setApprovalForAll(approvalAddress, true);
        staking.stake(LOW_VALUE_NFT, tokens, _singleAmountArray(tokens.length), 6, false);
        vm.stopPrank();

        // We should not be able to withdraw part way through, so we will expect a
        // revert if we try
        epochManager.setCurrentEpoch(52);
        vm.startPrank(LOW_HOLDER_2);
        vm.expectRevert('Cannot unstake portion');
        staking.unstake(LOW_VALUE_NFT, false);
        vm.stopPrank();

        // Skip some time to unlock our user, moving our epoch to the full stake period
        epochManager.setCurrentEpoch(104);

        // Unstake our NFTs
        vm.startPrank(LOW_HOLDER_2);
        staking.unstake(LOW_VALUE_NFT, false);

        // The NFTs returned will be the exact ones that the user initially put in
        assertEq(IERC721(LOW_VALUE_NFT).ownerOf(242), LOW_HOLDER_2);
        assertEq(IERC721(LOW_VALUE_NFT).ownerOf(5710), LOW_HOLDER_2);

        vm.stopPrank();
    }

    function test_CanUnstake1155() external {
        uint[] memory tokenIds = new uint[](1);
        tokenIds[0] = 1;

        uint[] memory tokenAmounts = new uint[](1);
        tokenAmounts[0] = 1;

        address approvalAddress = staking.nftStakingStrategy().approvalAddress();

        vm.startPrank(ERC1155_HOLDER);
        IERC1155(ERC1155_NFT).setApprovalForAll(approvalAddress, true);
        staking.stake(ERC1155_NFT, tokenIds, tokenAmounts, 6, true);
        vm.stopPrank();

        // We should not be able to withdraw part way through, so we will expect a
        // revert if we try
        epochManager.setCurrentEpoch(52);
        vm.startPrank(ERC1155_HOLDER);
        vm.expectRevert('Cannot unstake portion');
        staking.unstake(ERC1155_NFT, true);
        vm.stopPrank();

        // Skip some time to unlock our user, moving our epoch to the full stake period
        epochManager.setCurrentEpoch(104);

        // Unstake our NFTs
        vm.startPrank(ERC1155_HOLDER);
        staking.unstake(ERC1155_NFT, true);

        // The NFTs returned will be the exact ones that the user initially put in
        assertEq(IERC1155(ERC1155_NFT).balanceOf(ERC1155_HOLDER, 1), 1);

        // Confirm that we cannot unstake again
        vm.expectRevert('No tokens staked');
        staking.unstake(ERC1155_NFT, true);

        vm.stopPrank();
    }

    function test_CannotUnstakeFromUnknownCollection() external {
        vm.expectRevert('No tokens staked');
        vm.prank(LOW_HOLDER_2);
        staking.unstake(address(0), false);
    }

    function test_CannotUnstakeFromCollectionWithInsufficientPosition() external {
        vm.expectRevert('No tokens staked');
        vm.prank(LOW_HOLDER_2);
        staking.unstake(LOW_VALUE_NFT, false);
    }

    function test_CanClaimRewards() external {
        // TODO: ..
    }

    function _singleAmountArray(uint length) internal pure returns (uint[] memory amounts) {
        amounts = new uint[](length);
        for (uint i; i < length;) {
            amounts[i] = 1;
            unchecked {
                ++i;
            }
        }
    }
}
