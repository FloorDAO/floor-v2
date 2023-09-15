// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {
    CannotDepositZeroAmount,
    CannotWithdrawZeroAmount,
    InsufficientPosition,
    NFTXLiquidityPoolStakingStrategy
} from '@floor/strategies/NFTXLiquidityPoolStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';

import {INFTXLiquidityStaking} from '@floor-interfaces/nftx/NFTXLiquidityStaking.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NFTXLiquidityPoolStakingStrategyTest is FloorTest {
    // Store our strategy information
    NFTXLiquidityPoolStakingStrategy strategy;
    uint strategyId;
    address strategyImplementation;

    // Store internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_240_153;

    /// Define a number of ERC holders that we can test with
    address erc20Holder; // This will be set to `alice` during `setUp`
    address erc721Holder = 0xd938a84aD8CDB8385b68851350d5a84aA52D9C06; // Holds 411
    address erc1155Holder = 0xB45470a9688ec3bdBB572B27c305E8c45E014e75; // Holds ???

    /// Set up a {Treasury} contract address
    address treasury;

    // Define our WETH token
    IWETH WETH;

    // Set up a test user
    address alice;

    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        // Set up our strategy implementation
        strategyImplementation = address(new NFTXLiquidityPoolStakingStrategy());

        // Create our {CollectionRegistry} and approve our collection
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        // Approve our ERC721 collection
        collectionRegistry.approveCollection(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);
        // Approve our ERC1155 collection
        collectionRegistry.approveCollection(0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313);

        // Create our {StrategyRegistry} and approve our strategy implementation
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        strategyRegistry.approveStrategy(strategyImplementation, true);

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry)
        );

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('MILADY Liquidity Strategy'),
            strategyImplementation,
            abi.encode(
                392, // _vaultId
                0x15A8E38942F9e353BEc8812763fb3C104c89eCf4, // _underlyingToken     // MILADYWETH
                0x6c6BCe43323f6941FD6febe8ff3208436e8e0Dc7, // _yieldToken          // xMILADYWETH
                0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48, // _rewardToken         // MILADY
                0x688c3E4658B5367da06fd629E41879beaB538E37, // _liquidityStaking
                0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, // _stakingZap
                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 // _weth
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = NFTXLiquidityPoolStakingStrategy(_strategy);
        strategyId = _strategyId;

        // Set a {Treasury} address that we can treat as a recipient
        treasury = users[2];
        strategyFactory.setTreasury(treasury);

        // As the forked block has no non-contract holders of the ERC20 token, we send
        // some directly from the LP Staking contract to `alice` for testing
        erc20Holder = alice = users[1];
        vm.startPrank(address(strategy.liquidityStaking()));
        IERC20(strategy.underlyingToken()).transfer(alice, 100 ether);
        vm.stopPrank();

        // Set up our WETH token
        WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        // Deal some WETH to our erc holders so that we can action Liquidity stakes
        deal(address(WETH), address(erc721Holder), 100 ether);
        deal(address(WETH), address(erc1155Holder), 100 ether);
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'MILADY Liquidity Strategy');
    }

    /**
     * Our yield token should be the xToken that is defined by the
     * NFTX InventoryStaking contract.
     */
    function test_CanGetYieldToken() public {
        assertEq(strategy.yieldToken(), 0x6c6BCe43323f6941FD6febe8ff3208436e8e0Dc7);
    }

    /**
     * Our underlying token in our strategy is the NFTX ERC20 vault
     * token. This is normally be obtained through providing the NFT
     * to be deposited into the vault. We only want to accept the
     * already converted ERC20 vault token.
     *
     * This can be done through a zap, or just handled directly on
     * NFTX. This removes our requirement to inform users of the risks
     * that NFTX can impose.
     */
    function test_CanGetUnderlyingToken() public {
        assertEq(strategy.underlyingToken(), 0x15A8E38942F9e353BEc8812763fb3C104c89eCf4);
    }

    /**
     * Ensure we can get our reward token address.
     */
    function test_CanGetRewardToken() public {
        assertEq(strategy.rewardToken(), 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48);
    }

    /**
     * Ensures that we can correctly find the strategy ID that was deployed with the strategy.
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * This should return an xToken that is stored in the strategy.
     */
    function test_CanDepositErc20() public {
        vm.startPrank(erc20Holder);

        // Confirm our account has a balance of the underlying token
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(erc20Holder), 100 ether);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(erc20Holder), 0);

        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(strategy.underlyingToken()).approve(address(strategy), 10 ether);
        strategy.depositErc20(10 ether);

        assertEq(IERC20(strategy.underlyingToken()).balanceOf(erc20Holder), 90 ether);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(erc20Holder), 0);

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 10 ether);

        vm.stopPrank();
    }

    /**
     * If our strategy tries to deposit a token that is not supported
     * then we expect it to be reverted.
     */
    function test_CannotDepositErc20WithZeroAmount() public {
        vm.expectRevert(CannotDepositZeroAmount.selector);
        vm.prank(erc20Holder);
        strategy.depositErc20(0);
    }

    /**
     * We need to be able to claim all pending rewards from the NFTX
     * {InventoryStaking} contract. These should be put in the strategy
     * contract.
     */
    function test_CanWithdrawErc20() public {
        vm.startPrank(erc20Holder);

        // We first need to deposit
        IERC20(strategy.underlyingToken()).approve(address(strategy), 1 ether);
        uint depositAmount = strategy.depositErc20(1 ether);

        vm.stopPrank();

        // If we try to claim straight away, our user will be locked
        vm.expectRevert('Unable to withdraw'); // User locked
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Confirm that we cannot claim more than our token balance / position
        vm.expectRevert('Unable to withdraw'); // InsufficientPosition
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, depositAmount + 1));

        // Confirm our token holdings before we process a withdrawal
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(treasury), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 1 ether);

        // We can now claim rewards via the strategy that will eat away from our
        // deposit. For this test we will burn 0.5 xToken (yieldToken) to claim
        // back our underlying token.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));

        // The strategy should now hold a reduced amount of token and our {Treasury}
        // should hold the reward.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(treasury), 0.5 ether);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0.5 ether);
    }

    /**
     * We should be able to fully exit our position, having the all of
     * our vault ERC20 tokens returned and the xToken burnt from the
     * strategy.
     */
    function test_CanFullyExitPosition() public {
        vm.startPrank(erc20Holder);

        // Get the start balance of our {Treasury}
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(treasury)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(treasury)), 0);

        // We first need to deposit
        IERC20(strategy.underlyingToken()).approve(address(strategy), 1 ether);
        uint depositAmount = strategy.depositErc20(1 ether);

        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // We can now exit via the strategy. This will burn all of our xToken and
        // we will just have our `underlyingToken` back in the strategy.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, depositAmount));

        // The strategy should now hold token and xToken. However, we need to accomodate
        // for the dust bug in the InventoryStaking zap that leaves us missing 1 wei.
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0);

        // Check here for the sent value as well
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(treasury)), 1 ether);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(treasury)), 0);
    }

    /**
     * When we have rewards available we want to be able to determine
     * the token amount without needing to process a write call. This
     * will mean a much lower gas usage.
     */
    function test_CanDetermineRewardsAvailableAndClaim() public {
        vm.startPrank(erc20Holder);

        // Deposit using the underlying token to receive xToken into the strategy
        IERC20(strategy.underlyingToken()).approve(address(strategy), 5 ether);
        strategy.depositErc20(5 ether);

        vm.stopPrank();

        // At this point the strategy should hold "2986864760090612391" yield token, which at
        // the point the block was forked was the trade value.

        // Skip some time for the NFTX lock to expire. This will not change the value of the
        // yield token within the strategy.
        skip(2592001);

        // Check the balance directly that should be claimable, which will currently be zero
        // as no additional rewards have been generated.
        (, uint[] memory startRewardsAvailable) = strategy.available();
        assertEq(startRewardsAvailable[0], 0);

        // Check that we have the expected underlying, yield and reward tokens
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 5 ether);
        assertEq(IERC20(strategy.rewardToken()).balanceOf(address(strategy)), 0);

        // Generate some rewards by dealing xToken to our user
        deal(strategy.yieldToken(), address(strategy), 8 ether);

        // We need to distribute additional reward tokens to the to our LP staking contract
        // so that it has sufficient balance to fulfill our rewards.
        deal(strategy.rewardToken(), address(strategy.yieldToken()), 100 ether);

        // Check the balance directly that should be claimable
        (address[] memory rewardsTokens, uint[] memory rewardsAvailable) = strategy.available();
        assertEq(rewardsTokens[0], strategy.yieldToken());
        assertEq(rewardsAvailable[0], 11955376912380485207);

        // Check our lifetime rewards reflect this
        (address[] memory lifetimeRewardsTokens, uint[] memory lifetimeRewardsAvailable) = strategy.totalRewards();
        assertEq(lifetimeRewardsTokens[0], strategy.yieldToken());
        assertEq(lifetimeRewardsAvailable[0], 11955376912380485207);

        // Get the {Treasury} starting balance of the reward token
        uint treasuryStartBalance = IERC20(strategy.rewardToken()).balanceOf(treasury);
        assertEq(treasuryStartBalance, 0);

        // Claim our rewards via the strategy factory
        strategyFactory.harvest(strategyId);

        // Check the balance directly that should be claimable
        (, uint[] memory newRewardsAvailable) = strategy.available();
        assertEq(newRewardsAvailable[0], 0);

        // Check our lifetime rewards reflect this even after claiming
        (, uint[] memory newLifetimeRewardsAvailable) = strategy.totalRewards();
        assertEq(newLifetimeRewardsAvailable[0], 11955376912380485207);

        // Confirm that the {Treasury} has received the rewards
        uint treasuryEndBalance = IERC20(strategy.rewardToken()).balanceOf(treasury);
        assertEq(treasuryEndBalance, 11955376912380485207);
    }

    /**
     * Even when we have no rewards pending to be claimed, we don't want
     * the transaction to be reverted, but instead just return zero.
     */
    function test_CanDetermineRewardsAvailableWhenZero() public {
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], strategy.yieldToken());
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 0);
    }

    function test_CanDepositErc721() public {
        vm.startPrank(erc721Holder);

        // Confirm our account has a balance of the erc721 token
        assertEq(IERC721(strategy.assetAddress()).ownerOf(891), erc721Holder);
        assertEq(IERC721(strategy.assetAddress()).ownerOf(914), erc721Holder);

        // Build our token ID array
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 891;
        tokenIds[1] = 914;

        // Deposit using the ERC721 tokens to receive xToken into the strategy
        IERC721(strategy.assetAddress()).setApprovalForAll(address(strategy), true);
        WETH.approve(address(strategy), 20 ether);
        strategy.depositErc721(tokenIds, 0, 20 ether);

        // Confirm that the ERC721s are now held by the vault
        assertEq(IERC721(strategy.assetAddress()).ownerOf(891), strategy.rewardToken());
        assertEq(IERC721(strategy.assetAddress()).ownerOf(914), strategy.rewardToken());

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(IERC20(strategy.rewardToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.rewardToken()).balanceOf(treasury), 0);

        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 3695533293116565944);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(treasury), 0);

        vm.stopPrank();
    }

    function test_CanDepositErc1155() public {
        // Deploy a fresh NFTX strategy that supports an ERC1155 token
        (uint _strategyId, address _strategyAddress) = strategyFactory.deployStrategy(
            bytes32('CURIO Strategy'),
            strategyImplementation,
            abi.encode(
                241, // _vaultId
                0x8a83b072ca48c217c1ef676445A9a545c110A45B, // _underlyingToken     // CURIOWETH
                0x566f19428ca28923218bA74f54d3513F2ba719E1, // _yieldToken          // xCURIOWETH
                0xE97e496E8494232ee128c1a8cAe0b2B7936f3CaA, // _rewardToken         // CURIO
                0x688c3E4658B5367da06fd629E41879beaB538E37, // _liquidityStaking
                0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, // _stakingZap
                0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 // _weth
            ),
            0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        NFTXLiquidityPoolStakingStrategy _strategy = NFTXLiquidityPoolStakingStrategy(_strategyAddress);

        vm.startPrank(erc1155Holder);

        // Confirm our account has a balance of the erc721 token
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 1), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 2), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 7), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(_strategy.rewardToken(), 1), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(_strategy.rewardToken(), 2), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(_strategy.rewardToken(), 7), 13);

        // Build our token ID array
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Approve our WETH allocation for the strategy
        WETH.approve(address(_strategy), 5 ether);

        // Deposit using the ERC721 tokens to receive xToken into the strategy
        IERC1155(_strategy.assetAddress()).setApprovalForAll(address(_strategy), true);
        _strategy.depositErc1155(tokenIds, amounts, 0, 5 ether);

        // Confirm that, although we sent 5 WETH that we have received an amount back. This
        // account started with 100 WETH, so we can use that as a base to test from.
        assertEq(WETH.balanceOf(erc1155Holder), 99732516493129423305); // 100 ether - 2.7~ ether

        // Confirm that the ERC721s are now held by the vault
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 1), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 2), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 7), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(_strategy.rewardToken(), 1), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(_strategy.rewardToken(), 2), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(_strategy.rewardToken(), 7), 13);

        // Determine our initial balances following a deposit of 2 tokens and WETH to match
        assertEq(IERC20(_strategy.underlyingToken()).balanceOf(address(_strategy)), 0);
        assertEq(IERC20(_strategy.underlyingToken()).balanceOf(treasury), 0);
        assertEq(IERC20(_strategy.yieldToken()).balanceOf(address(_strategy)), 725256818397827410);
        assertEq(IERC20(_strategy.yieldToken()).balanceOf(treasury), 0);
        assertEq(IERC20(_strategy.rewardToken()).balanceOf(address(_strategy)), 0);
        assertEq(IERC20(_strategy.rewardToken()).balanceOf(treasury), 0);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        vm.stopPrank();

        // We can now call the strategy to withdraw an NFT token and some partial token
        strategyFactory.withdraw(_strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));

        vm.startPrank(erc1155Holder);

        // Our token holdings should be reduced to cover the withdrawal, and also show that the
        // {Treasury} now holds the expected amount of underlying token.
        assertEq(IERC20(_strategy.underlyingToken()).balanceOf(address(_strategy)), 0);
        assertEq(IERC20(_strategy.underlyingToken()).balanceOf(treasury), 500000000000000000);
        assertEq(IERC20(_strategy.yieldToken()).balanceOf(address(_strategy)), 225256818397827410);
        assertEq(IERC20(_strategy.yieldToken()).balanceOf(treasury), 0);
        assertEq(IERC20(_strategy.rewardToken()).balanceOf(address(_strategy)), 0);
        assertEq(IERC20(_strategy.rewardToken()).balanceOf(treasury), 0);

        vm.stopPrank();
    }

    function test_CanWithdrawWithoutAffectingYieldEarned() public {
        vm.startPrank(erc20Holder);

        // We deposit 8 vToken
        IERC20(strategy.underlyingToken()).approve(address(strategy), 8 ether);
        strategy.depositErc20(8 ether);

        vm.stopPrank();

        // Our 8 vToken deposit gives us a 1:1 yield token
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 8000000000000000000);

        // Confirm our rewards generated at first deposit will be zero
        assertRewards(strategy, 0, 0, 0, 0);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Generate rewards worth of 2 ETH using a mocked call
        address[] memory rewardToken = new address[](1);
        rewardToken[0] = strategy.yieldToken();
        uint[] memory rewardAmount = new uint[](1);
        rewardAmount[0] = 2 ether;

        vm.mockCall(
            address(strategy),
            abi.encodeWithSelector(NFTXLiquidityPoolStakingStrategy.available.selector),
            abi.encode(rewardToken, rewardAmount)
        );

        // Confirm our rewards generated after mocking our rewards are updated
        assertRewards(strategy, 2 ether, 2 ether, 0, 0);

        // Withdraw ETH from our position
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 1 ether));

        // Confirm our rewards generated after withdrawing from our initial deposit
        assertRewards(strategy, 2 ether, 2 ether, 0, 0);

        // Our strategy should now hold 7 xToken
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 7000000000000000000);

        // Snapshot the rewards
        strategyFactory.snapshot(strategyId, 0);

        // Withdraw another xToken
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 1 ether));

        // Confirm that we still have 2 ETH of rewards
        assertRewards(strategy, 2 ether, 2 ether, 0, 2 ether);

        // Our strategy should now hold 6 xToken
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 6000000000000000000);

        // Before we can harvest, we need to mock the NFTX calls as we won't actually have
        // any tokens available to claim.
        vm.mockCall(address(strategy.liquidityStaking()), abi.encodeWithSelector(INFTXLiquidityStaking.withdraw.selector), abi.encode(true));
        vm.mockCall(strategy.yieldToken(), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

        // Harvest our rewards via the strategy
        strategyFactory.harvest(strategyId);

        // Update our `available` mock
        rewardAmount[0] = 0;
        vm.mockCall(
            address(strategy),
            abi.encodeWithSelector(NFTXLiquidityPoolStakingStrategy.available.selector),
            abi.encode(rewardToken, rewardAmount)
        );

        // Confirm our closing strategy data is correct
        assertRewards(strategy, 2 ether, 0, 2 ether, 2 ether);
    }

    /**
     * Ensures that we have the correct tokens attached to the strategy.
     */
    function test_CanGetValidTokens() public {
        address[] memory tokens = strategy.validTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], strategy.underlyingToken());
    }

    function test_CanWithdrawPercentage() public {
        // Confirm that our tests don't have any residual tokens to start with
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(this)), 0);
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 0);

        // Deposit into our strategy
        vm.startPrank(erc20Holder);
        IERC20(strategy.underlyingToken()).approve(address(strategy), 1 ether);
        strategy.depositErc20(1 ether);
        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Action a 20% percentage withdrawal through the strategy factory
        strategyFactory.withdrawPercentage(address(strategy), 2000);

        // Confirm that our recipient received the expected amount of tokens
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(this)), 2e17);

        // Confirm that the strategy still holds the expected number of yield token
        assertEq(IERC20(strategy.underlyingToken()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(strategy.yieldToken()).balanceOf(address(strategy)), 8e17);

        // Confirm that the strategy has an accurate record of the deposits
        uint deposits = strategy.deposits();
        assertEq(deposits, 8e17);
    }

    function assertRewards(
        NFTXLiquidityPoolStakingStrategy _strategy,
        uint _rewardAmount,
        uint _availableAmount,
        uint _lifetimeRewards,
        uint _lastEpochRewards
    ) internal {
        (, uint[] memory totalRewardAmounts) = _strategy.totalRewards();
        (, uint[] memory totalAvailableAmounts) = _strategy.available();
        uint lifetimeRewards = _strategy.lifetimeRewards(_strategy.yieldToken());
        uint lastEpochRewards = _strategy.lastEpochRewards(_strategy.yieldToken());

        assertEq(totalRewardAmounts[0], _rewardAmount);
        assertEq(totalAvailableAmounts[0], _availableAmount);
        assertEq(lifetimeRewards, _lifetimeRewards);
        assertEq(lastEpochRewards, _lastEpochRewards);
    }
}
