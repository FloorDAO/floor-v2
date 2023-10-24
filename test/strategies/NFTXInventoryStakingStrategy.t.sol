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
    NFTXInventoryStakingStrategy
} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';

import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract NFTXInventoryStakingStrategyTest is FloorTest {
    // Store our strategy information
    NFTXInventoryStakingStrategy strategy;
    uint strategyId;
    address strategyImplementation;

    // Store internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 17_240_153;

    /// Define a number of ERC holders that we can test with
    address erc20Holder = 0x56bf24f635B39aC01DA6761C69AEe7ba4f1cFE3f;
    address erc721Holder = 0xd938a84aD8CDB8385b68851350d5a84aA52D9C06;
    address erc1155Holder = 0xB45470a9688ec3bdBB572B27c305E8c45E014e75;

    /// Set up a {Treasury} contract address
    address treasury;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();
    }

    function setUp() public {
        // Set up our strategy implementation
        strategyImplementation = address(new NFTXInventoryStakingStrategy());

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
            bytes32('MILADY Strategy'),
            strategyImplementation,
            abi.encode(
                392, // _vaultId
                0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48, // _vToken
                0x5D1C5Dee420004767d3e2fb7AA7C75AA92c33117, // _xToken
                0x3E135c3E981fAe3383A5aE0d323860a34CfAB893, // _inventoryStaking
                0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, // _stakingZap
                0x2374a32ab7b4f7BE058A69EA99cb214BFF4868d3 // _unstakingZap
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = NFTXInventoryStakingStrategy(_strategy);
        strategyId = _strategyId;

        // Set a {Treasury} address that we can treat as a recipient
        treasury = users[2];
        strategyFactory.setTreasury(treasury);
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'MILADY Strategy');
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
     *
     * Our yield token should be the xToken that is defined by the
     * NFTX InventoryStaking contract.
     */
    function test_CanGetTokens() public {
        assertEq(address(strategy.vToken()), 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48);
        assertEq(address(strategy.xToken()), 0x5D1C5Dee420004767d3e2fb7AA7C75AA92c33117);
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
        assertEq(strategy.vToken().balanceOf(erc20Holder), 8000000000000000000);
        assertEq(strategy.xToken().balanceOf(erc20Holder), 0);

        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        strategy.vToken().approve(address(strategy), 1 ether);
        strategy.depositErc20(1 ether);

        assertEq(strategy.vToken().balanceOf(erc20Holder), 7000000000000000000);
        assertEq(strategy.xToken().balanceOf(erc20Holder), 0);

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 597372952018122478);

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
        strategy.vToken().approve(address(strategy), 1 ether);
        strategy.depositErc20(1 ether);

        vm.stopPrank();

        // If we try to claim straight away, our user will be locked
        vm.expectRevert('Unable to withdraw'); // User locked
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Confirm that we cannot claim more than our token balance / position
        vm.expectRevert('Unable to withdraw'); // InsufficientPosition
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 100 ether));

        // Confirm our token holdings before we process a withdrawal
        assertEq(strategy.vToken().balanceOf(treasury), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 597372952018122478);

        // We can now claim rewards via the strategy that will eat away from our
        // deposit. For this test we will burn to receive 0.5 vToken.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));

        // The strategy should now hold a reduced amount of token and our {Treasury}
        // should hold the reward.
        assertEq(strategy.vToken().balanceOf(treasury), 0.5 ether - 1);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 597372952018122478 / 2);
    }

    /**
     * We should be able to fully exit our position, having the all of
     * our vault ERC20 tokens returned and the xToken burnt from the
     * strategy.
     */
    function test_CanFullyExitPosition() public {
        vm.startPrank(erc20Holder);

        // Get the start balance of our {Treasury}
        assertEq(strategy.vToken().balanceOf(address(treasury)), 0);
        assertEq(strategy.xToken().balanceOf(address(treasury)), 0);

        // We first need to deposit
        strategy.vToken().approve(address(strategy), 1 ether);
        strategy.depositErc20(1 ether);

        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // We can now exit via the strategy. This will burn all of our xToken and
        // we will just have our `underlyingToken` back in the strategy.
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, strategy.deposits()));

        // The strategy should now hold token and xToken. However, we need to accomodate
        // for the dust bug in the InventoryStaking zap that leaves us missing 1 wei.
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 0);

        // Check that the amount withdrawn went to the right place
        assertEq(strategy.vToken().balanceOf(address(treasury)), 1 ether - 1);
        assertEq(strategy.xToken().balanceOf(address(treasury)), 0);

        // Confirm that our deposits are now empty. This will be offset by the
        // annoying dust bug.
        assertEq(strategy.deposits(), 1);
    }

    /**
     * When we have rewards available we want to be able to determine
     * the token amount without needing to process a write call. This
     * will mean a much lower gas usage.
     */
    function test_CanDetermineRewardsAvailableAndClaim() public {
        vm.startPrank(erc20Holder);

        // Deposit using the underlying token to receive xToken into the strategy
        strategy.vToken().approve(address(strategy), 5 ether);
        strategy.depositErc20(5 ether);

        vm.stopPrank();

        // At this point the strategy should hold "2986864760090612391" yield token, which at
        // the point the block was forked was the trade value.

        // Skip some time for the NFTX lock to expire. This will not change the value of the
        // yield token within the strategy.
        skip(2592001);

        // Check the balance directly that should be claimable
        (, uint[] memory startRewardsAvailable) = strategy.available();

        assertEq(strategy.deposits(), 5 ether);
        assertEq(startRewardsAvailable[0], 0);

        /*
        // Generate some rewards by dealing xToken to our user
        // TODO: Update method of reward distribution
        // deal(strategy.xToken(), address(strategy), 8 ether);

        // Check the balance directly that should be claimable
        (address[] memory rewardsTokens, uint[] memory rewardsAvailable) = strategy.available();
        assertEq(rewardsTokens[0], address(strategy.xToken()));
        assertEq(rewardsAvailable[0], 5013135239909387609);

        // Check our lifetime rewards reflect this
        (address[] memory lifetimeRewardsTokens, uint[] memory lifetimeRewardsAvailable) = strategy.totalRewards();
        assertEq(lifetimeRewardsTokens[0], address(strategy.xToken()));
        assertEq(lifetimeRewardsAvailable[0], 5013135239909387609);

        // Get the {Treasury} starting balance of the reward token
        uint treasuryStartBalance = strategy.vToken().balanceOf(treasury);
        assertEq(treasuryStartBalance, 0);

        // Claim our rewards via the strategy factory
        strategyFactory.harvest(strategyId);

        // Check the balance directly that should be claimable
        (, uint[] memory newRewardsAvailable) = strategy.available();
        assertEq(newRewardsAvailable[0], 0);

        // Check our lifetime rewards reflect this even after claiming
        (, uint[] memory newLifetimeRewardsAvailable) = strategy.totalRewards();
        assertEq(newLifetimeRewardsAvailable[0], 5013135239909387609);

        // Confirm that the {Treasury} has received the rewards
        uint treasuryEndBalance = strategy.vToken().balanceOf(treasury);
        assertEq(treasuryEndBalance, 8391968908155895774);
        */
    }

    /**
     * Even when we have no rewards pending to be claimed, we don't want
     * the transaction to be reverted, but instead just return zero.
     */
    function test_CanDetermineRewardsAvailableWhenZero() public {
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(strategy.vToken()));
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
        strategy.depositErc721(tokenIds);

        // Confirm that the ERC721s are now held by the NFTX vault
        assertEq(IERC721(strategy.assetAddress()).ownerOf(891), address(strategy.vToken()));
        assertEq(IERC721(strategy.assetAddress()).ownerOf(914), address(strategy.vToken()));

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.vToken().balanceOf(treasury), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 1194745904036244956);
        assertEq(strategy.xToken().balanceOf(treasury), 0);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        vm.stopPrank();

        // We can now call the strategy to withdraw an NFT token and some partial token
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc721.selector, 1, 0.5 ether));

        vm.startPrank(erc721Holder);

        // Our token holdings should be reduced to cover the withdrawal, and also show that the
        // {Treasury} now holds the expected amount of underlying token. This drops 1 wei due to
        // a known NFTX bug.
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.vToken().balanceOf(treasury), 499999999999999999);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 298686476009061239);
        assertEq(strategy.xToken().balanceOf(treasury), 0);

        // The redeemed NFT would normally be pseudo-random, but as we have a hard fork of
        // the block, we should see it to be the same each time.
        assertEq(IERC721(strategy.assetAddress()).ownerOf(8360), treasury);

        vm.stopPrank();
    }

    function test_CanDepositErc1155() public {
        // Deploy a fresh NFTX strategy that supports an ERC1155 token
        (uint _strategyId, address _strategyAddress) = strategyFactory.deployStrategy(
            bytes32('CURIO Strategy'),
            strategyImplementation,
            abi.encode(
                241, // _vaultId
                0xE97e496E8494232ee128c1a8cAe0b2B7936f3CaA, // _underlyingToken
                0xf80ffB0699B8d97E9fD198cCBc367A47b77a9d1C, // _yieldToken
                0x3E135c3E981fAe3383A5aE0d323860a34CfAB893, // _inventoryStaking
                0xdC774D5260ec66e5DD4627E1DD800Eff3911345C, // _stakingZap
                0x2374a32ab7b4f7BE058A69EA99cb214BFF4868d3 // _unstakingZap
            ),
            0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        NFTXInventoryStakingStrategy _strategy = NFTXInventoryStakingStrategy(_strategyAddress);

        vm.startPrank(erc1155Holder);

        // Confirm our account has a balance of the erc721 token
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 1), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 2), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 13), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 1), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 2), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 13), 56);

        // Build our token ID array
        uint[] memory tokenIds = new uint[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint[] memory amounts = new uint[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Deposit using the ERC721 tokens to receive xToken into the strategy
        IERC1155(_strategy.assetAddress()).setApprovalForAll(address(_strategy), true);
        _strategy.depositErc1155(tokenIds, amounts);

        // Confirm that the ERC721s are now held by the vault
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 1), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 2), 0);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 13), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 1), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 2), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 13), 56);

        // The amount of xToken returned to the strategy is less than 1, because this uses
        // xToken share value. This is expected to be variable and less that the depositted
        // amount.
        assertEq(IERC20(_strategy.vToken()).balanceOf(address(_strategy)), 0);
        assertEq(IERC20(_strategy.vToken()).balanceOf(treasury), 0);
        assertEq(IERC20(_strategy.xToken()).balanceOf(address(_strategy)), 1745467356927040912);
        assertEq(IERC20(_strategy.xToken()).balanceOf(treasury), 0);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        vm.stopPrank();

        // We can now call the strategy to withdraw an NFT token and some partial token
        strategyFactory.withdraw(_strategyId, abi.encodeWithSelector(_strategy.withdrawErc721.selector, 1, 0.5 ether));

        vm.startPrank(erc1155Holder);

        // Our token holdings should be reduced to cover the withdrawal, and also show that the
        // {Treasury} now holds the expected amount of underlying token. This drops 1 wei due to
        // a known NFTX bug.
        assertEq(IERC20(_strategy.vToken()).balanceOf(address(_strategy)), 0);
        assertEq(IERC20(_strategy.vToken()).balanceOf(treasury), 499999999999999999);
        assertEq(IERC20(_strategy.xToken()).balanceOf(address(_strategy)), 436366839231760228);
        assertEq(IERC20(_strategy.xToken()).balanceOf(treasury), 0);

        // The redeemed NFT would normally be pseudo-random, but as we have a hard fork of
        // the block, we should see it to be the same each time.
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(erc1155Holder, 13), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(treasury, 13), 1);
        assertEq(IERC1155(_strategy.assetAddress()).balanceOf(address(_strategy.vToken()), 13), 55);

        vm.stopPrank();
    }

    function test_CanWithdrawWithoutAffectingYieldEarned() public {
        vm.startPrank(erc20Holder);

        // We deposit 8 vToken
        strategy.vToken().approve(address(strategy), 8 ether);
        strategy.depositErc20(8 ether);

        vm.stopPrank();

        // Our 8 vToken deposit gives us 4.77 xToken
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 4778983616144979825);

        // Confirm our rewards generated at first deposit will be zero
        assertRewards(
            strategy,  // NFTXInventoryStakingStrategy _strategy
            0,         // uint _rewardAmount
            0,         // uint _availableAmount
            0,         // uint _lifetimeRewards
            0          // uint _lastEpochRewards
        );

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Generate rewards worth of 2 ETH using a mocked call
        address[] memory rewardToken = new address[](1);
        rewardToken[0] = address(strategy.vToken());
        uint[] memory rewardAmount = new uint[](1);
        rewardAmount[0] = 2 ether;

        vm.mockCall(
            address(strategy),
            abi.encodeWithSelector(NFTXInventoryStakingStrategy.available.selector),
            abi.encode(rewardToken, rewardAmount)
        );

        // Confirm our rewards generated after mocking our rewards are updated
        assertRewards(
            strategy,  // NFTXInventoryStakingStrategy _strategy
            2 ether,   // uint _rewardAmount
            2 ether,   // uint _availableAmount
            0,         // uint _lifetimeRewards
            0          // uint _lastEpochRewards
        );

        // Withdraw ETH from our position
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 1 ether));

        // Our strategy should now hold a reduced amount of xToken
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 4181610664126857347);

        // Snapshot the rewards
        strategyFactory.snapshot(strategyId, 0);

        // Withdraw another xToken
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 1 ether));

        // Confirm that we still have 2 ETH of rewards, and now that our snapshot has been
        // taken we shoud see this register in the `lastEpochRewards`.
        assertRewards(
            strategy,
            2 ether,
            2 ether,
            0,
            2 ether
        );

        // Our strategy should now hold 2.77 xToken
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 3584237712108734869);

        // Before we can harvest, we need to mock the NFTX calls as we won't actually have
        // any tokens available to claim.
        vm.mockCall(address(strategy.inventoryStaking()), abi.encodeWithSelector(INFTXInventoryStaking.withdraw.selector), abi.encode(true));
        vm.mockCall(address(strategy.xToken()), abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));

        // Harvest our rewards via the strategy
        strategyFactory.harvest(strategyId);

        // Update our `available` mock
        rewardAmount[0] = 0;
        vm.mockCall(
            address(strategy),
            abi.encodeWithSelector(NFTXInventoryStakingStrategy.available.selector),
            abi.encode(rewardToken, rewardAmount)
        );

        // Confirm our closing strategy data is correct
        assertRewards(
            strategy,  // NFTXInventoryStakingStrategy _strategy
            2 ether,   // uint _rewardAmount
            0,         // uint _availableAmount
            2 ether,   // uint _lifetimeRewards
            2 ether    // uint _lastEpochRewards
        );
    }

    /**
     * Ensures that we have the correct tokens attached to the strategy.
     */
    function test_CanGetValidTokens() public {
        address[] memory tokens = strategy.validTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(strategy.vToken()));
    }

    function test_CanWithdrawPercentage() public {
        // Deposit into our strategy
        vm.startPrank(erc20Holder);
        strategy.vToken().approve(address(strategy), 1 ether);
        strategy.depositErc20(1 ether);
        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Action a 20% percentage withdrawal through the strategy factory
        strategyFactory.withdrawPercentage(address(strategy), 2000);

        // Confirm that our recipient received the expected amount of tokens
        assertEq(strategy.vToken().balanceOf(address(this)), 199999999999999998);

        // Confirm that the strategy still holds the expected number of yield token
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 477898361614497983);

        // Confirm that the strategy has an accurate record of the deposits
        uint deposits = strategy.deposits();
        assertEq(deposits, 800000000000000002);
    }

    function assertRewards(
        NFTXInventoryStakingStrategy _strategy,
        uint _rewardAmount,
        uint _availableAmount,
        uint _lifetimeRewards,
        uint _lastEpochRewards
    ) internal {
        (, uint[] memory totalRewardAmounts) = _strategy.totalRewards();
        (, uint[] memory totalAvailableAmounts) = _strategy.available();
        uint lifetimeRewards = _strategy.lifetimeRewards(address(_strategy.vToken()));
        uint lastEpochRewards = _strategy.lastEpochRewards(address(_strategy.vToken()));

        assertEq(totalRewardAmounts[0], _rewardAmount, 'Incorrect totalRewards');
        assertEq(totalAvailableAmounts[0], _availableAmount, 'Incorrect available');
        assertEq(lifetimeRewards, _lifetimeRewards, 'Incorrect lifetimeRewards');
        assertEq(lastEpochRewards, _lastEpochRewards, 'Incorrect lastEpochRewards');
    }
}
