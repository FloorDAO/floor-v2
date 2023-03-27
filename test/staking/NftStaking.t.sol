// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {NftStaking} from '@floor/staking/NftStaking.sol';
import {NftStakingNFTXV2} from '@floor/staking/NftStakingNFTXV2.sol';
import {NftStakingBoostCalculator} from '@floor/staking/NftStakingBoostCalculator.sol';
import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';
import {EpochManager} from '@floor/EpochManager.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NftStakingTest is FloorTest {
    address constant LOW_VALUE_NFT = 0x524cAB2ec69124574082676e6F654a18df49A048;
    address constant HIGH_VALUE_NFT = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;

    address constant LOW_HOLDER_1 = 0x488C636D0a928aeCE719519FBe0cf171B442aBd8;
    address constant LOW_HOLDER_2 = 0x8c0d2B62F133Db265EC8554282eE60EcA0Fd5a9E;
    address constant LOW_HOLDER_3 = 0xA52899A1A8195c3Eef30E0b08658705250E154aE;

    address constant HIGH_HOLDER_1 = 0xa523dA93344dD163C32a8cD9A31459eAD1d86B0A;

    // Test users
    address alice;

    uint16 constant VOTE_DISCOUNT = 4000; // 40%

    uint constant NFTX_LOCK_LENGTH = 2592001;

    // Internal contract references
    EpochManager epochManager;
    NftStaking staking;
    NftStakingNFTXV2 nftStakingStrategy;
    UniswapV3PricingExecutor pricingExecutor;

    constructor() forkBlock(16_692_005) {
        // Map our test user(s)
        alice = users[0];

        // Set up our pricing executor mock that will allow us to control set vote
        // amounts returned in our tests.
        pricingExecutor = new UniswapV3PricingExecutor(
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0xf59257E961883636290411c11ec5Ae622d19455e
        );

        // Set up our epoch manager so that our staking contract has visibility of
        // epoch transitions.
        epochManager = new EpochManager();

        // Set up our staking contract
        staking = new NftStaking(address(pricingExecutor), VOTE_DISCOUNT);

        // Set up our staking strategy
        nftStakingStrategy = new NftStakingNFTXV2(address(staking));

        // Set our staking zaps to the correct mainnet addresses
        nftStakingStrategy.setStakingZaps(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, 0x2374a32ab7b4f7BE058A69EA99cb214BFF4868d3);

        // Add our underlying token mappings
        nftStakingStrategy.setUnderlyingToken(LOW_VALUE_NFT, 0xB603B3fc4B5aD885e26298b7862Bb6074dff32A9, 0xEB07C09A72F40818704a70F059D1d2c82cC54327);
        nftStakingStrategy.setUnderlyingToken(HIGH_VALUE_NFT, 0x269616D549D7e8Eaa82DFb17028d0B212D11232A, 0x08765C76C758Da951DC73D3a8863B34752Dd76FB);

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

    function test_CannotDeployContractWithInvalidParameters() external {
        vm.expectRevert();
        new NftStaking(address(0), VOTE_DISCOUNT);

        vm.expectRevert();
        new NftStaking(address(pricingExecutor), 10000);
    }

    /**
     * When we have no staked NFTs, we still receive a multiplier amount of 100% as this
     * means that we aren't increase the base value by any amount. A returned value of 0
     * would result in all votes being nullified.
     */
    function test_CanGetCollectionBoostWhenZero() external {
        assertEq(staking.collectionBoost(alice), 1000000000);
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

        // User 1 stakes 5 NFT for 104 epochs
        vm.startPrank(LOW_HOLDER_1);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, lowTokens1, 6);
        vm.stopPrank();

        // User 2 stakes 2 NFT for 52 epochs
        vm.startPrank(LOW_HOLDER_2);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, lowTokens2, 4);
        vm.stopPrank();

        // User 3 stakes 8 NFT for 26 epochs
        vm.startPrank(LOW_HOLDER_3);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, lowTokens3, 3);
        vm.stopPrank();

        assertEq(staking.collectionBoost(LOW_VALUE_NFT), 1610730439);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1000000000);

        // User 4 stakes 1 high value NFT for 104 epochs
        vm.startPrank(HIGH_HOLDER_1);
        (bool success,) = address(HIGH_VALUE_NFT).call(
            abi.encodeWithSignature('offerPunkForSaleToAddress(uint256,uint256,address)', highTokens1[0], 0, address(staking))
        );
        require(success, 'Failed to offer PUNK');
        staking.stake(HIGH_VALUE_NFT, highTokens1, 6);
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

    function test_CannotStakeUnownedNft() external {
        uint[] memory tokens = new uint[](1);
        tokens[0] = 1;

        vm.expectRevert('ERC721: transfer caller is not owner nor approved');
        staking.stake(LOW_VALUE_NFT, tokens, 6);
    }

    function test_CannotStakeInvalidCollectionNft() external {
        uint[] memory tokens = new uint[](1);
        tokens[0] = 992;

        vm.expectRevert('Underlying token not found');
        vm.prank(0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96);
        staking.stake(0xE63bE4Ed45D32e43Ff9b53AE9930983B0367330a, tokens, 6);
    }

    function test_CannotStakeNftForInvalidEpochCount() external {
        uint[] memory tokens = new uint[](2);
        tokens[0] = 242;
        tokens[1] = 5710;

        vm.startPrank(LOW_HOLDER_2);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);

        vm.expectRevert('Invalid epoch index');
        staking.stake(LOW_VALUE_NFT, tokens, 7);
        vm.stopPrank();
    }

    function test_CanUnstake() external {
        uint[] memory tokens = new uint[](2);
        tokens[0] = 242;
        tokens[1] = 5710;

        vm.startPrank(LOW_HOLDER_2);
        // Stake 2 tokens
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, tokens, 6);
        vm.stopPrank();

        // Skip some time to unlock our user, moving our epoch to the full stake period
        epochManager.setCurrentEpoch(104);
        skip(NFTX_LOCK_LENGTH);

        // Unstake our NFTs
        vm.startPrank(LOW_HOLDER_2);
        staking.unstake(LOW_VALUE_NFT);

        // The NFTs would normally be random, but since we are locked at a specific time, the
        // pseudo-randomness that NFTX applies will give us a consistent return.
        assertEq(IERC721(LOW_VALUE_NFT).ownerOf(5174), LOW_HOLDER_2);
        assertEq(IERC721(LOW_VALUE_NFT).ownerOf(7439), LOW_HOLDER_2);
        assertEq(IERC20(nftStakingStrategy.underlyingToken(LOW_VALUE_NFT)).balanceOf(LOW_HOLDER_2), 0);

        vm.stopPrank();
    }

    function test_CanUnstakeEarlyWithAPenalty() external {
        uint[] memory tokens = new uint[](2);
        tokens[0] = 242;
        tokens[1] = 5710;

        vm.startPrank(LOW_HOLDER_2);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, tokens, 6);
        vm.stopPrank();

        // Skip some time to unlock our user, moving our epoch only partially through stake
        epochManager.setCurrentEpoch(78);
        skip(NFTX_LOCK_LENGTH);

        // Unstake our NFTs which should give us one full NFT and some ERC dust
        vm.startPrank(LOW_HOLDER_2);
        staking.unstake(LOW_VALUE_NFT);

        // The NFTs would normally be random, but since we are locked at a specific time, the
        // pseudo-randomness that NFTX applies will give us a consistent return.
        assertEq(IERC721(LOW_VALUE_NFT).ownerOf(5174), LOW_HOLDER_2);
        assertEq(IERC20(nftStakingStrategy.underlyingToken(LOW_VALUE_NFT)).balanceOf(LOW_HOLDER_2), 499999999999999999);

        vm.stopPrank();
    }

    function test_CannotUnstakeFromUnknownCollection() external {
        vm.expectRevert('No tokens staked');
        vm.prank(LOW_HOLDER_2);
        staking.unstake(address(0));
    }

    function test_CannotUnstakeFromCollectionWithInsufficientPosition() external {
        vm.expectRevert('No tokens staked');
        vm.prank(LOW_HOLDER_2);
        staking.unstake(LOW_VALUE_NFT);
    }

    function test_CanSetVoteDiscount(uint16 amount) external {
        vm.assume(amount >= 0);
        vm.assume(amount < 10000);

        staking.setVoteDiscount(amount);
        assertEq(staking.voteDiscount(), amount);
    }

    function test_CannotSetInvalidVoteDiscount(uint16 amount) external {
        vm.assume(amount >= 10000);

        vm.expectRevert();
        staking.setVoteDiscount(amount);

        assertEq(staking.voteDiscount(), VOTE_DISCOUNT);
    }

    function test_CannotSetVoteDiscountWithoutPermission() external {
        vm.expectRevert();
        vm.prank(alice);
        staking.setVoteDiscount(VOTE_DISCOUNT);
    }

    function test_CanSetPricingExecutor() external {
        staking.setPricingExecutor(address(1));
        assertEq(address(staking.pricingExecutor()), address(1));
    }

    function test_CannotSetInvalidPricingExecutor() external {
        vm.expectRevert();
        staking.setPricingExecutor(address(0));
    }

    function test_CannotSetPricingExecutorWithoutPermission() external {
        vm.expectRevert();
        vm.prank(alice);
        staking.setPricingExecutor(address(pricingExecutor));
    }

    function test_CanSetStakingZaps() external {
        nftStakingStrategy.setStakingZaps(address(1), address(2));

        assertEq(address(nftStakingStrategy.stakingZap()), address(1));
        assertEq(address(nftStakingStrategy.unstakingZap()), address(2));
    }

    function test_CannotSetInvalidStakingZaps() external {
        vm.expectRevert();
        nftStakingStrategy.setStakingZaps(address(1), address(0));

        vm.expectRevert();
        nftStakingStrategy.setStakingZaps(address(0), address(1));

        vm.expectRevert();
        nftStakingStrategy.setStakingZaps(address(0), address(0));
    }

    function test_CannotSetStakingZapsWithoutPermission() external {
        vm.expectRevert();
        vm.prank(alice);
        nftStakingStrategy.setStakingZaps(address(1), address(2));
    }

    function test_CanSetBoostCalculator() external {
        staking.setBoostCalculator(address(1));
    }

    function test_CannotSetInvalidBoostCalculator() external {
        vm.expectRevert();
        staking.setBoostCalculator(address(0));
    }

    function test_CannotSetBoostCalculatorWithoutPermissions() external {
        vm.startPrank(alice);

        address newStakingCalculator = address(new NftStakingBoostCalculator());

        vm.expectRevert();
        staking.setBoostCalculator(newStakingCalculator);

        vm.stopPrank();
    }

    function test_CanClaimRewards() external {
        // TODO: ..
    }
}
