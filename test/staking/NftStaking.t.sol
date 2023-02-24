// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {NftStaking} from '@floor/staking/NftStaking.sol';
import {UniswapV3PricingExecutor} from '@floor/pricing/UniswapV3PricingExecutor.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NftStakingTest is FloorTest {

    address constant LOW_VALUE_NFT  = 0x524cAB2ec69124574082676e6F654a18df49A048;
    address constant HIGH_VALUE_NFT = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;

    address constant LOW_HOLDER_1  = 0x488C636D0a928aeCE719519FBe0cf171B442aBd8;
    address constant LOW_HOLDER_2  = 0x8c0d2B62F133Db265EC8554282eE60EcA0Fd5a9E;
    address constant LOW_HOLDER_3  = 0xA52899A1A8195c3Eef30E0b08658705250E154aE;

    address constant HIGH_HOLDER_1 = 0xa523dA93344dD163C32a8cD9A31459eAD1d86B0A;

    // Test users
    address alice;

    uint constant VOTE_DISCOUNT = 4000;  // 40%

    // Internal contract references
    NftStaking staking;
    UniswapV3PricingExecutor pricingExecutor;

    constructor () forkBlock(16_692_005) {
        // Map our test user(s)
        alice = users[0];

        // Set up our pricing executor mock that will allow us to control set vote
        // amounts returned in our tests.
        pricingExecutor = new UniswapV3PricingExecutor(
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0xf59257E961883636290411c11ec5Ae622d19455e
        );

        // Set up our staking contract
        staking = new NftStaking(address(pricingExecutor), VOTE_DISCOUNT);

        // Set our staking zaps to the correct mainnet addresses
        staking.setStakingZaps(
            0xdC774D5260ec66e5DD4627E1DD800Eff3911345C,
            0x2374a32ab7b4f7BE058A69EA99cb214BFF4868d3
        );

        // Add our underlying token mappings
        // TODO: This should be done when we approve a collection
        staking.setUnderlyingToken(LOW_VALUE_NFT,  0xB603B3fc4B5aD885e26298b7862Bb6074dff32A9);
        staking.setUnderlyingToken(HIGH_VALUE_NFT, 0x269616D549D7e8Eaa82DFb17028d0B212D11232A);

        staking.setSweepModifier(4e9);
    }

    function test_CannotDeployContractWithInvalidParameters() external {
        vm.expectRevert();
        new NftStaking(address(0), VOTE_DISCOUNT);

        vm.expectRevert();
        new NftStaking(address(pricingExecutor), 10000);
    }

    function test_CanGetCollectionBoostWhenZero() external {
        assertEq(staking.collectionBoost(alice), 0);
    }

    function test_CanGetVoteBoostWithSingleCollection() external {
        uint[] memory lowTokens1  = new uint[](5);
        lowTokens1[0] = 16543;
        lowTokens1[1] = 1672;
        lowTokens1[2] = 4774;
        lowTokens1[3] = 4818;
        lowTokens1[4] = 5587;

        uint[] memory lowTokens2  = new uint[](2);
        lowTokens2[0] = 242;
        lowTokens2[1] = 5710;

        uint[] memory lowTokens3  = new uint[](8);
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
        staking.stake(LOW_VALUE_NFT, lowTokens1, 104);
        vm.stopPrank();

        // User 2 stakes 2 NFT for 52 epochs
        vm.startPrank(LOW_HOLDER_2);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, lowTokens2, 52);
        vm.stopPrank();

        // User 3 stakes 8 NFT for 26 epochs
        vm.startPrank(LOW_HOLDER_3);
        IERC721(LOW_VALUE_NFT).setApprovalForAll(address(staking), true);
        staking.stake(LOW_VALUE_NFT, lowTokens3, 26);
        vm.stopPrank();

        assertEq(staking.collectionBoost(LOW_VALUE_NFT),  1610730439);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1000000000);

        // User 4 stakes 1 high value NFT for 104 epochs
        vm.startPrank(HIGH_HOLDER_1);
        (bool success,) = address(HIGH_VALUE_NFT).call(abi.encodeWithSignature("offerPunkForSaleToAddress(uint256,uint256,address)", highTokens1[0], 0, address(staking)));
        require(success, 'Failed to offer PUNK');
        staking.stake(HIGH_VALUE_NFT, highTokens1, 104);
        vm.stopPrank();

        assertEq(staking.collectionBoost(LOW_VALUE_NFT),  1610730439);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1106073976);

        // Skip forward 52 epochs
        staking.setCurrentEpoch(staking.currentEpoch() + 26);

        // Get the total sweep power against gauge 1
        assertEq(staking.collectionBoost(LOW_VALUE_NFT),  1150729596);
        assertEq(staking.collectionBoost(HIGH_VALUE_NFT), 1071691143);
    }

    function test_CannotStakeUnownedNft() external {}
    function test_CannotStakeInvalidCollectionNft() external {}
    function test_CannotStakeNftForInvalidEpochCount() external {}

    function test_CanUnstakeSingleToken() external {}
    function test_CanUnstakeMultipleTokens() external {}
    function test_CannotUnstakeFromUnknownCollection() external {}
    function test_CannotUnstakeFromCollectionWithInsufficientPosition() external {}

    function test_CanSetVoteDiscount() external {}
    function test_CannotSetInvalidVoteDiscount() external {}

    function test_CanSetPricingExecutor() external {}
    function test_CannotSetInvalidPricingExecutor() external {}

    function test_CanSetStakingZaps() external {}
    function test_CannotSetInvalidStakingZaps() external {}

    function test_CanClaimRewards() external {}

}
