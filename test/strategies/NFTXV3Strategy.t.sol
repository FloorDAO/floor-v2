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
    NFTXV3Strategy
} from '@floor/strategies/NFTXV3Strategy.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';

import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';

import {FloorTest} from '../utilities/Environments.sol';

interface IMintableERC721 {
    function mint(uint count) external returns (uint[] memory tokenIds);
}

contract NFTXV3StrategyTest is FloorTest {
    // Store our strategy information
    NFTXV3Strategy strategy;
    uint strategyId;
    address strategyImplementation;

    // Store internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 4_826_898;

    /// Define a number of ERC holders that we can test with
    address erc20Holder = 0xCCa280c616df940D8114384302Ae09765A507938; // 8 PUDGY
    address erc721Holder = 0xd938a84aD8CDB8385b68851350d5a84aA52D9C06;
    address erc1155Holder = 0xB45470a9688ec3bdBB572B27c305E8c45E014e75;

    /// Set up a {Treasury} contract address
    address treasury;

    constructor() {
        // Generate a Sepolia fork
        uint sepoliaFork = vm.createFork(vm.rpcUrl('sepolia'));

        // Select our fork for the VM
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(BLOCK_NUMBER);
        require(block.number == BLOCK_NUMBER);

        // Deploy our authority contracts
        super._deployAuthority();
    }

    function setUp() public {
        // Set up our strategy implementation
        strategyImplementation = address(new NFTXV3Strategy());

        // Create our {CollectionRegistry} and approve our collection
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Approve our ERC721 collection (Pudgy Penguins)
        collectionRegistry.approveCollection(0x5Af0D9827E0c53E4799BB226655A1de152A425a5);

        // Approve our ERC1155 collection
        // collectionRegistry.approveCollection(0x73DA73EF3a6982109c4d5BDb0dB9dd3E3783f313);

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
            bytes32('Pudgy Penguin Strategy'),
            strategyImplementation,
            abi.encode(
                6,  // Pudgy Penguins Vault ID
                0xfBFf0635f7c5327FD138E1EBa72BD9877A6a7C1C  // INFTXInventoryStakingV3
            ),
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = NFTXV3Strategy(payable(_strategy));
        strategyId = _strategyId;

        // Set a {Treasury} address that we can treat as a recipient
        treasury = users[2];
        strategyFactory.setTreasury(treasury);
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'Pudgy Penguin Strategy');
    }

    /**
     * Our vToken in our strategy is the NFTX ERC20 vault token. This is normally
     * be obtained through providing the NFT to be deposited into the vault. We
     * only want to accept the already converted ERC20 vault token.
     *
     * The xToken will be the WETH address for the network.
     */
    function test_CanGetTokens() public {
        assertEq(address(strategy.vToken()), 0xcD20F8E170a7B7371F093879570C1a7e0FB82104);
        assertEq(address(strategy.xToken()), 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);
    }

    /**
     * Ensures that we have the correct tokens attached to the strategy.
     */
    function test_CanGetValidTokens() public {
        address[] memory tokens = strategy.validTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(strategy.vToken()));
    }

    /**
     * Ensures that we can correctly find the strategy ID that was deployed with the strategy.
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * This should accept vToken and return the amount of xToken that was received and stored
     * in the strategy.
     */
    function test_CanDepositErc20() public {
        vm.startPrank(erc20Holder);

        // Confirm that our initial parent position ID is zero, as this is our first deposit
        assertEq(strategy.parentPositionId(), 0);

        // Confirm our account has a balance of the underlying token and holds no xToken
        assertEq(strategy.vToken().balanceOf(erc20Holder), 8 ether);
        assertEq(strategy.xToken().balanceOf(erc20Holder), 0);

        // Our strategy should currently hold no tokens
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 0);

        // Deposit using the underlying token to receive xToken into the strategy
        strategy.vToken().approve(address(strategy), 5 ether);
        strategy.depositErc20(5 ether);

        // Confirm the ERC20 holder has had their vToken balance reduced, but not received
        // any xToken back directly.
        assertEq(strategy.vToken().balanceOf(erc20Holder), 3 ether);
        assertEq(strategy.xToken().balanceOf(erc20Holder), 0);

        // Our strategy should now hold a vTokenShare, which doesn't directly relate to a
        // vToken or xToken. We first confirm that we hold no tokens.
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 0);

        // Now that we have made a deposit, our parent position ID should have been updated
        assertEq(strategy.parentPositionId(), 21);

        // We can now confirm that the vTokenShare of the strategy is reflected correctly
        (,,,,, uint vTokenShareBalance,, uint wethOwed) = strategy.staking().positions(strategy.parentPositionId());
        assertEq(vTokenShareBalance, 5 ether);
        assertEq(wethOwed, 0);

        // Our strategy should also track this position amount
        assertEq(strategy.position(address(strategy.vToken())), 5 ether);

        vm.stopPrank();
    }

    /**
     * After we have made an initial deposit, or subsequent deposits should just increase
     * our position, rather than creating a new one.
     *
     * @dev Our holder starts with 8 tokens.
     */
    function test_CanDepositErc20MultipleTimesToIncreasePosition() public {
        vm.startPrank(erc20Holder);

        // Our position should start with a zero value
        assertEq(strategy.parentPositionId(), 0);

        // Approve all tokens
        strategy.vToken().approve(address(strategy), 8 ether);

        // Make our initial deposit
        strategy.depositErc20(2 ether);

        // Our position should now have a value
        assertEq(strategy.parentPositionId(), 21);

        // Make our subsequent deposit
        strategy.depositErc20(1 ether);

        // Our position should still have the same value
        assertEq(strategy.parentPositionId(), 21);

        // Confirm our holder and strategy balances
        assertEq(strategy.vToken().balanceOf(erc20Holder), 5 ether);
        (,,,,, uint vTokenShareBalance,,) = strategy.staking().positions(strategy.parentPositionId());
        assertEq(vTokenShareBalance, 3 ether);

        // Our strategy should also track this position amount
        assertEq(strategy.position(address(strategy.vToken())), 3 ether);

        vm.stopPrank();
    }

    /**
     * If our strategy tries to deposit a token with zero value, then we expect
     * it to be reverted.
     */
    function test_CannotDepositErc20WithZeroAmount() public {
        vm.expectRevert(CannotDepositZeroAmount.selector);
        vm.prank(erc20Holder);
        strategy.depositErc20(0);
    }

    function test_CanDepositErc721(uint tokens) public {
        // We only want to use 1 - 50 tokens
        tokens = bound(tokens, 1, 50);

        // Mint NFTs from the 721 collection
        uint[] memory tokenIds = IMintableERC721(strategy.assetAddress()).mint(tokens);
        uint[] memory amounts = new uint[](tokenIds.length);

        // Deposit using the ERC721 tokens to receive a vToken position into the strategy
        IERC721(strategy.assetAddress()).setApprovalForAll(address(strategy), true);
        strategy.depositNfts(tokenIds, amounts);

        // Confirm that we now have an equivalent vTokenShare
        assertEq(strategy.position(address(strategy.vToken())), tokens * 1 ether);
        (,,,,, uint vTokenShareBalance,,) = strategy.staking().positions(strategy.parentPositionId());
        assertEq(vTokenShareBalance, tokens * 1 ether);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // We can now call the strategy to withdraw an NFT token and some partial token
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, 0.5 ether));

        // Our token holdings should be reduced to cover the withdrawal, and also show that the
        // {Treasury} now holds the expected amount of underlying token.
        assertEq(strategy.vToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.vToken().balanceOf(treasury), 0.5 ether);
        assertEq(strategy.xToken().balanceOf(address(strategy)), 0);
        assertEq(strategy.xToken().balanceOf(treasury), 0);

        // Confirm our remaining position
        assertEq(strategy.position(address(strategy.vToken())), (tokens * 1 ether) - 0.5 ether);
        (,,,,, vTokenShareBalance,,) = strategy.staking().positions(strategy.parentPositionId());
        assertEq(vTokenShareBalance, (tokens * 1 ether) - 0.5 ether);
    }

    function test_CanCombinePositions() public {
        // Approve all NFT tokens
        IERC721(strategy.assetAddress()).setApprovalForAll(address(strategy), true);

        // Deposit into an initial position
        vm.startPrank(erc20Holder);
        strategy.vToken().approve(address(strategy), type(uint).max);
        strategy.depositErc20(5 ether);
        vm.stopPrank();

        // Warp past the parent timelock
        vm.warp(block.timestamp + 1 hours);

        // We should now have a parent position and no child positions
        assertEq(strategy.parentPositionId(), 21);
        uint[] memory childPositionIds = strategy.positionIds();
        assertEq(childPositionIds.length, 0);

        // Deposit some NFTs which will create a new position
        uint[] memory tokenIds = IMintableERC721(strategy.assetAddress()).mint(2);
        uint[] memory amounts = new uint[](tokenIds.length);
        strategy.depositNfts(tokenIds, amounts);

        // We should now have a parent position and a single child position
        assertEq(strategy.parentPositionId(), 21);
        childPositionIds = strategy.positionIds();
        assertEq(childPositionIds.length, 1);
        assertEq(childPositionIds[0], 22);

        // Warp a little before the first timelock
        vm.warp(block.timestamp + 450);

        // Deposit some NFTs which will create a new position
        tokenIds = IMintableERC721(strategy.assetAddress()).mint(3);
        amounts = new uint[](tokenIds.length);
        strategy.depositNfts(tokenIds, amounts);

        // We should now have a parent position and two child positions
        assertEq(strategy.parentPositionId(), 21);
        childPositionIds = strategy.positionIds();
        assertEq(childPositionIds.length, 2);
        assertEq(childPositionIds[0], 22);
        assertEq(childPositionIds[1], 23);

        // Warp past the first timelock
        vm.warp(block.timestamp + 450);

        // Deposit some NFTs which will combine the first position and create
        // a new position.
        tokenIds = IMintableERC721(strategy.assetAddress()).mint(1);
        amounts = new uint[](tokenIds.length);
        strategy.depositNfts(tokenIds, amounts);

        // We should now have a parent position and two child positions, as one will
        // have been merged in.
        assertEq(strategy.parentPositionId(), 21);
        childPositionIds = strategy.positionIds();
        assertEq(childPositionIds.length, 2);
        assertEq(childPositionIds[0], 23);
        assertEq(childPositionIds[1], 24);

        // Warp past all the timelocks
        vm.warp(block.timestamp + 12 hours);

        // Make an ERC20 deposit, which will merge the vTokenShare
        vm.prank(erc20Holder);
        strategy.depositErc20(2 ether);

        // We should now have no pending position IDs, and all of our vTokens should
        // be in the parent position.
        assertEq(strategy.parentPositionId(), 21);
        childPositionIds = strategy.positionIds();
        assertEq(childPositionIds.length, 0);
    }

    function test_CanWithdrawErc20(uint depositAmount, uint withdrawAmount, uint inventoryEth) public {
        // If the inventory staking contract holds ETH, then it will additionally refund this
        // to our strategy. We can additionally set this in our test to validate this logic. We
        // place an upper limit assumption on this value to prevent an `OverflowPayment` error.
        vm.assume(inventoryEth < type(uint128).max);
        if (inventoryEth > 0) {
            deal(address(strategy.staking()), inventoryEth);
        }

        vm.startPrank(erc20Holder);

        // Ensure that we don't try to deposit more than our balance
        vm.assume(depositAmount > 1);
        vm.assume(depositAmount <= 8 ether);

        // Ensure that we don't try to withdraw more than our deposit
        vm.assume(withdrawAmount > 0);
        vm.assume(withdrawAmount <= depositAmount);

        // We first need to deposit
        strategy.vToken().approve(address(strategy), type(uint).max);
        strategy.depositErc20(depositAmount);

        vm.stopPrank();

        // If we try to claim straight away, our user will be locked
        vm.expectRevert('Unable to withdraw'); // Timelocked
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, withdrawAmount));

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired. We can find this from our position.
        (,,,, uint vTokenTimelockedUntil, uint vTokenShareBalance,,) = strategy.staking().positions(strategy.parentPositionId());

        // @dev We must warp to _AFTER_ the timelock
        vm.warp(vTokenTimelockedUntil + 1);

        // Confirm that we have the expected amount of vTokenShares to withdraw against
        assertEq(vTokenShareBalance, depositAmount);

        // Confirm that we cannot claim more than our token balance / position
        vm.expectRevert('Unable to withdraw'); // InsufficientPosition
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, depositAmount + 1));

        // We can now make a successful withdraw against the strategy
        strategyFactory.withdraw(strategyId, abi.encodeWithSelector(strategy.withdrawErc20.selector, withdrawAmount));

        // The strategy should now hold a reduced amount of token
        (,,,,, vTokenShareBalance,,) = strategy.staking().positions(strategy.parentPositionId());
        assertEq(vTokenShareBalance, depositAmount - withdrawAmount);

        // Our {Treasury} should hold the reward
        assertEq(strategy.vToken().balanceOf(treasury), withdrawAmount);

        // If the inventory staking contract holds ETH, then we also need to check that we received
        // this and wrapped it into WETH.
        assertEq(strategy.xToken().balanceOf(address(strategy)), inventoryEth);
    }

    /**
     * We need to be able to request a percentage withdraw, in addition to a specific
     * amount of vToken.
     */
    function test_CanWithdrawPercentage() public {
        // Deposit directly into our strategy
        vm.startPrank(erc20Holder);
        strategy.vToken().approve(address(strategy), 8 ether);
        strategy.depositErc20(8 ether);
        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Action a 20% percentage withdrawal through the strategy factory
        strategyFactory.withdrawPercentage(address(strategy), 2500);

        // Confirm that our recipient received the expected amount of tokens. The recipient
        // for this function call is the `msg.sender`.
        assertEq(strategy.vToken().balanceOf(address(this)), 2 ether);

        // The strategy should now hold a reduced amount of token
        (,,,,, uint vTokenShareBalance,,) = strategy.staking().positions(strategy.parentPositionId());
        assertEq(vTokenShareBalance, 8 ether - 2 ether);
    }

    /**
     * When we have rewards available we want to be able to determine
     * the token amount without needing to process a write call. This
     * will mean a much lower gas usage.
     */
    function test_CanDetermineRewardsAvailableAndClaim() public {
        vm.startPrank(erc20Holder);

        // Deposit using the underlying token
        strategy.vToken().approve(address(strategy), 5 ether);
        strategy.depositErc20(5 ether);

        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired. We can find this from our position.
        // @dev We must warp to _AFTER_ the timelock
        (,,,, uint vTokenTimelockedUntil,,,) = strategy.staking().positions(strategy.parentPositionId());
        vm.warp(vTokenTimelockedUntil + 1);

        // Check the balance directly that should be claimable
        (, uint[] memory startRewardsAvailable) = strategy.available();

        // Confirm that we have nothing to claim yet
        assertEq(startRewardsAvailable[0], 0);

        // Distribute WETH rewards into the vault
        _distributeWethRewards(strategy.vaultId(), 10 ether);

        // Check the balance directly that should be claimable
        (address[] memory rewardsTokens, uint[] memory rewardsAvailable) = strategy.available();
        assertEq(rewardsTokens[0], address(strategy.xToken()));
        assertEq(rewardsAvailable[0], 1_111808971265018476);

        // Check our lifetime rewards reflect this
        (address[] memory lifetimeRewardsTokens, uint[] memory lifetimeRewardsAvailable) = strategy.totalRewards();
        assertEq(lifetimeRewardsTokens[0], address(strategy.xToken()));
        assertEq(lifetimeRewardsAvailable[0], 1_111808971265018476);

        // Get the {Treasury} starting balance of the reward token
        uint treasuryStartBalance = strategy.xToken().balanceOf(treasury);
        assertEq(treasuryStartBalance, 0);

        // Claim our rewards via the strategy factory
        strategyFactory.harvest(strategyId);

        // Check the balance directly that should be claimable
        (, uint[] memory newRewardsAvailable) = strategy.available();
        assertEq(newRewardsAvailable[0], 0);

        // Check our lifetime rewards reflect this even after claiming
        (, uint[] memory newLifetimeRewardsAvailable) = strategy.totalRewards();
        assertEq(newLifetimeRewardsAvailable[0], 1_111808971265018476);

        // Confirm that the {Treasury} has received the rewards
        uint treasuryEndBalance = strategy.xToken().balanceOf(treasury);
        assertEq(treasuryEndBalance, 1_111808971265018476);
    }

    /**
     * Even when we have no rewards pending to be claimed, we don't want
     * the transaction to be reverted, but instead just return zero.
     */
    function test_CanDetermineRewardsAvailableWhenZero() public {
        (address[] memory tokens, uint[] memory amounts) = strategy.available();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(strategy.xToken()));
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 0);
    }

    function _distributeWethRewards(uint vaultId, uint wethRewards) internal {
        // Provide the contract enough ETH to wrap
        deal(address(this), wethRewards);

        // Capture the NFTX Fee Distributor address
        address feeDistributor = address(strategy.staking().nftxVaultFactory().feeDistributor());

        // Provide the Fee Distributor with the WETH
        strategy.xToken().deposit{value: wethRewards}();
        strategy.xToken().transfer(feeDistributor, wethRewards);

        vm.startPrank(feeDistributor);
        strategy.xToken().approve(address(strategy.staking()), type(uint).max);
        strategy.staking().receiveWethRewards(vaultId, wethRewards);
        vm.stopPrank();
    }

}
