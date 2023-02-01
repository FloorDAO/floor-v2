// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../src/contracts/authorities/AuthorityRegistry.sol';
import '../../src/contracts/collections/CollectionRegistry.sol';
import '../../src/contracts/strategies/StrategyRegistry.sol';
import '../../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import '../../src/contracts/tokens/Floor.sol';
import '../../src/contracts/tokens/VaultXToken.sol';
import '../../src/contracts/vaults/Vault.sol';
import '../../src/contracts/vaults/VaultFactory.sol';

import '../../src/interfaces/strategies/BaseStrategy.sol';

import '../utilities/Environments.sol';

contract VaultTest is FloorTest {
    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_075_930;

    /// Reference our vault through our tests
    IBaseStrategy strategy;
    FLOOR floor;
    Vault vault;
    VaultFactory vaultFactory;
    VaultXToken xToken;

    /// A wallet that holds PUNK token at the block
    address private constant PUNK_HOLDER = 0x0E239772E3BbfD125E7a9558ccb93D34946caD18;
    uint private constant PUNK_BALANCE = 676000177241559782;

    /// Another wallet that holds PUNK token at the block
    address private constant PUNK_HOLDER_2 = 0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB;
    uint private constant PUNK_BALANCE_2 = 450220188060663039;

    /**
     * Our set up logic creates a valid {Vault} instance that we will
     * subsequently test against.
     */
    constructor() forkBlock(BLOCK_NUMBER) {
        // Create our {StrategyRegistry}
        StrategyRegistry strategyRegistry = new StrategyRegistry(address(authorityRegistry));

        // Set up an inventory staking strategy
        strategy = new NFTXInventoryStakingStrategy(bytes32('PUNK'));

        // Approve our test strategy implementation
        strategyRegistry.approveStrategy(address(strategy));

        // Create our {CollectionRegistry}
        CollectionRegistry collectionRegistry = new CollectionRegistry(address(authorityRegistry));

        // Approve our test collection
        collectionRegistry.approveCollection(0x269616D549D7e8Eaa82DFb17028d0B212D11232A);

        // Deploy our vault implementation
        address vaultImplementation = address(new Vault());

        // Deploy our vault implementation
        address vaultXTokenImplementation = address(new VaultXToken());

        // Deploy our FLOOR token
        floor = new FLOOR(address(authorityRegistry));

        // Create our {VaultFactory}
        vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            vaultImplementation,
            vaultXTokenImplementation,
            address(floor)
        );

        // Set up our Vault with authority
        (, address vaultAddress) = vaultFactory.createVault(
            'Test Vault',
            address(strategy),
            abi.encode(
                0x269616D549D7e8Eaa82DFb17028d0B212D11232A, // _underlyingToken
                0x08765C76C758Da951DC73D3a8863B34752Dd76FB, // _yieldToken
                0x3E135c3E981fAe3383A5aE0d323860a34CfAB893  // _inventoryStaking
            ),
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A
        );

        vault = Vault(vaultAddress);
        xToken = VaultXToken(vault.xToken());

        vm.label(vaultAddress, 'Test Vault');
        vm.label(vault.xToken(), 'Test Vault xToken');
        vm.label(address(vault.strategy()), 'Test Vault Strategy');
        vm.label(vault.collection(), 'Test Vault Collection');
    }

    /**
     * This helper function gets the contract address of the collection tied to
     * the vault.
     */
    function test_CanGetCollectionAddress() public {
        assertEq(vault.collection(), 0x269616D549D7e8Eaa82DFb17028d0B212D11232A);
    }

    /**
     * This helper function gets the strategy address of the collection tied to
     * the vault. This will be the `cloneDeterministic` strategy address that is
     * applied to the vault, not the strategy contract address passed.
     */
    function test_CanGetStrategyAddress() public {
        assertEq(address(vault.strategy()), 0xcb3E70C6E6Bd8112951D06adf3DCe0bE8A8aa749);
    }

    /**
     * This helper function gets the vault factory address of the contract that
     * created the vault.
     */
    function test_CanGetVaultFactoryAddress() public {
        assertEq(vault.vaultFactory(), address(vaultFactory));
    }

    /**
     * The vault ID attributed when the vault is created will be made available
     * via this helper function call.
     */
    function test_CanGetVaultId() public {
        assertEq(vault.vaultId(), 0);
    }

    /**
     * We should be able to deposit any amount of approved tokens that match
     * the collection contract address. The return value will be the amount
     * of the deposit made, although in reality it is the total of all deposits
     * made by the sender and currently held in contract.
     *
     * Assets should be help in the vault until the strategy calls to stake
     * them.
     */
    function test_CanDeposit(uint amount) public {
        // Avoid dust being returned and getting reverted
        vm.assume(amount > 1000 && amount <= PUNK_BALANCE);

        // Confirm our starting ERC20 token balance
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        // Confirm our starting ERC20 xToken balance
        assertEq(xToken.balanceOf(PUNK_HOLDER), 0);
        assertEq(xToken.balanceOf(address(strategy)), 0);
        assertEq(xToken.balanceOf(address(vault)), 0);

        // We should currently hold a 0% share of the vault
        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);

        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Make a deposit from our user and get back the received number of xTokens. The
        // number of xTokens is the amount allocated to the position, not the deposit
        // amount itself.
        uint receivedAmount = vault.deposit(amount);

        vm.stopPrank();

        // The holder will now have a reduced balance
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount);

        // Our strategy and vault won't hold the token, as the NFTX vault will hold it
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        // As we have not yet passed the epoch, the user will still hold no xToken
        assertEq(xToken.balanceOf(PUNK_HOLDER), 0);
        assertEq(xToken.balanceOf(address(strategy)), 0);
        assertEq(xToken.balanceOf(address(vault)), 0);

        // Our position and share will still be zero, as it will be stored as pending
        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.pendingPositions(PUNK_HOLDER), receivedAmount);
        assertEq(vault.share(PUNK_HOLDER), 0);

        // After migrating our pending deposits, we migrate the pending positions to
        // actual positions and the share will be recalculated.
        vaultFactory.migratePendingDeposits(vault.vaultId());

        assertEq(vault.position(PUNK_HOLDER), receivedAmount);
        assertEq(vault.pendingPositions(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        assertEq(xToken.balanceOf(PUNK_HOLDER), receivedAmount);
        assertEq(xToken.balanceOf(address(strategy)), 0);
        assertEq(xToken.balanceOf(address(vault)), 0);
    }

    /**
     * A user should be able to make multiple subsequent deposits into the
     * contract. The return value should be the cumulative value of all
     * deposits made in the test.
     */
    function test_CanDepositMultipleTimes(uint amount1, uint amount2) public {
        // Avoid dust and ensure that the sum is less that our user's total balance
        vm.assume(amount1 > 10000 && amount1 < PUNK_BALANCE / 2);
        vm.assume(amount2 > 10000 && amount2 < PUNK_BALANCE / 2);

        // Confirm our start balances
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(xToken.balanceOf(PUNK_HOLDER), 0);
        assertEq(xToken.balanceOf(address(strategy)), 0);
        assertEq(xToken.balanceOf(address(vault)), 0);

        // Our helper calls should show empty also
        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);

        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Make 2 varied size deposits into our user's position. The second deposit will
        // return the cumulative user's position that includes both deposit returns.
        uint receivedAmount1 = vault.deposit(amount1);
        assertEq(vault.pendingPositions(PUNK_HOLDER), receivedAmount1);

        uint receivedAmount2 = vault.deposit(amount2);
        assertEq(vault.pendingPositions(PUNK_HOLDER), receivedAmount1 + receivedAmount2);

        vm.stopPrank();

        // After the deposits, we should have a reduced balance but have 0 position as we
        // have not yet refreshed the epoch / pending deposits.
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount1 - amount2);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        assertEq(xToken.balanceOf(PUNK_HOLDER), 0);
        assertEq(xToken.balanceOf(address(strategy)), 0);
        assertEq(xToken.balanceOf(address(vault)), 0);

        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.pendingPositions(PUNK_HOLDER), receivedAmount1 + receivedAmount2);
        assertEq(vault.share(PUNK_HOLDER), 0);

        // Trigger our pending deposit migration
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // We should now see our user's position
        assertEq(vault.position(PUNK_HOLDER), receivedAmount1 + receivedAmount2);
        assertEq(vault.pendingPositions(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        assertEq(xToken.balanceOf(PUNK_HOLDER), receivedAmount1 + receivedAmount2);
        assertEq(xToken.balanceOf(address(strategy)), 0);
        assertEq(xToken.balanceOf(address(vault)), 0);
    }

    /**
     * If the sender has not approved their token to be transferred, then
     * we should expect a revert.
     */
    function test_CannotDepositWithoutApproval() public {
        vm.expectRevert('ERC20: transfer amount exceeds balance');
        vault.deposit(50000);
    }

    /**
     * If the sender does not have a sufficient balance of tokens to be
     * transferred, then we should expect a revert.
     */
    function test_CannotDepositWithoutSufficientBalance() public {
        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Try and deposit more tokens that our user has
        vm.expectRevert('ERC20: transfer amount exceeds balance');
        vault.deposit(10 ether);

        vm.stopPrank();
    }

    /**
     * If the sender attempts to send a ETH to the contract then we should
     * just revert the transaction.
     */
    function test_CannotSendETH() public {
        // Give our prank account 100 ETH to test
        vm.deal(PUNK_HOLDER, 100 ether);
        vm.startPrank(PUNK_HOLDER);

        // Send ETH from our user to the vault
        (bool success,) = address(vault).call{value: 10 ether}('');
        assertEq(success, false);

        vm.stopPrank();
    }

    /**
     * A sender should be able to withdraw fully from their staked position.
     */
    function test_CanWithdrawPartially(uint amount) public {
        // Prevent our deposit from returning a 0 amount from staking
        vm.assume(amount > 10000);

        // Make a deposit of our full balance. This will return a slightly different
        // amount in xToken terms.
        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        uint depositAmount = vault.deposit(PUNK_BALANCE);
        vm.stopPrank();

        // Ensure that our test amount is less that or equal to the amount of xToken
        // received from our deposit.
        vm.assume(amount <= depositAmount);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // We will process our vault shares to commit our pending position to an
        // actual position.
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Process a withdrawal of a partial amount against our position
        vm.startPrank(PUNK_HOLDER);
        uint withdrawalAmount = vault.withdraw(amount);
        vm.stopPrank();

        // Our holder should now have just the withdrawn amount back in their wallet
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), withdrawalAmount);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // Our holder should have an xToken amount remaining equal to what is left
        // in the amount not withdrawn.
        assertEq(xToken.balanceOf(PUNK_HOLDER), depositAmount - amount);

        // The holders position should be their entire balance, minus the amount that
        // was withdrawn. This will still leave our holder with a 100% vault share.
        assertEq(vault.position(PUNK_HOLDER), depositAmount - amount);
        assertEq(vault.share(PUNK_HOLDER), 10000);
    }

    /**
     * A sender should be able to withdraw partially from their staked position.
     */
    function test_CanWithdrawFully(uint amount) public {
        // Prevent our deposit from returning a 0 amount from staking
        vm.assume(amount > 10000 && amount <= PUNK_BALANCE);

        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Deposit an amount of tokens that the holder has approved
        uint depositAmount = vault.deposit(amount);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Withdraw the same amount that we depositted
        uint withdrawalAmount = vault.withdraw(depositAmount);

        // We need to take our base balance, minus the dust lost during the deposit
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount + withdrawalAmount);

        // There will be dust left in the strategy and vault
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // Our user should hold no position, nor share
        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);

        vm.stopPrank();
    }

    /**
     * ..
     */
    function test_CanWithdrawFromPendingPosition(uint amount1, uint amount2) public {
        // Ensure that the combined amounts don't go above our available balance
        vm.assume(amount1 > 1000 && amount2 > 1000);
        vm.assume(amount1 <= PUNK_BALANCE / 2 && amount2 <= PUNK_BALANCE / 2);
        vm.assume(amount1 < amount2);

        // Approve use of PUNK token
        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), PUNK_BALANCE);

        // We can deposit our first value and calculate our shares to move this deposit
        // position from pending to active
        uint depositAmount1 = vault.deposit(amount1);
        vm.stopPrank();

        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Make our second deposit that will remain in pending
        vm.startPrank(PUNK_HOLDER);
        uint depositAmount2 = vault.deposit(amount2);
        vm.stopPrank();

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Confirm our expected position and pending position
        assertEq(vault.position(PUNK_HOLDER), depositAmount1);
        assertEq(vault.pendingPositions(PUNK_HOLDER), depositAmount2);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        // We can process our first withdrawal, and because `amount1` is less that
        // `amount2`, we know that there will still be a partial `pendingPosition` left
        // for the user, and their full actual position.
        vm.startPrank(PUNK_HOLDER);
        uint withdrawalAmount1 = vault.withdraw(depositAmount1);
        vm.stopPrank();

        // This will leave the user with 100% share still, as well as their full
        // position, but their pending position will have been reduced.
        assertEq(vault.position(PUNK_HOLDER), depositAmount1);
        assertEq(vault.pendingPositions(PUNK_HOLDER), depositAmount2 - depositAmount1);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        // Now we want to remove the remaining position, which will be reduced from
        // both the pending and actual position.
        vm.startPrank(PUNK_HOLDER);
        uint withdrawalAmount2 = vault.withdraw(depositAmount2);
        vm.stopPrank();

        // Our user should now have the complete withdrawn amount in their balance
        assertEq(
            IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount1 - amount2 + withdrawalAmount1 + withdrawalAmount2
        );

        // Vault and Strategy should have no holdings
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // Our user's remaining position should now be empty
        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.pendingPositions(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);
    }

    /**
     * A sender should be able to make multiple withdrawal calls.
     */
    function test_CanWithdrawMultipleTimes(uint amount) public {
        vm.assume(amount > 10000);

        // Deposit enough to make sufficiently make 2 withdrawals of our fuzzy value
        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        uint depositAmount = vault.deposit(PUNK_BALANCE);
        vm.stopPrank();

        vm.assume(amount < depositAmount / 2);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // We will process our vault shares to commit our pending position to an
        // actual position.
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Process 2 vault withdrawals
        vm.startPrank(PUNK_HOLDER);
        uint withdrawalAmount1 = vault.withdraw(amount);
        uint withdrawalAmount2 = vault.withdraw(amount);
        vm.stopPrank();

        // Our user should now have the twice withdrawn amount in their balance
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), withdrawalAmount1 + withdrawalAmount2);

        // Vault and Strategy should have no holdings
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // Our user's remaining position should be calculated by the amount deposited,
        // minus the amount withdrawn (done twice).
        assertEq(vault.position(PUNK_HOLDER), depositAmount - amount - amount);
        assertEq(vault.pendingPositions(PUNK_HOLDER), 0);

        // Since we left at least some dust in the position, we can assert that the
        // holder as 100% of the share.
        assertEq(vault.share(PUNK_HOLDER), 10000);
    }

    /**
     * If a sender does not has a sufficient balance to withdraw from then
     * we should revert the call.
     */
    function test_CannotWithdrawWithoutSufficientBalance() public {
        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Try and deposit more tokens that our user has
        vault.deposit(500000);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Expect our call to be reverted as we are trying to withdraw twice the amount
        // that we deposited.
        vm.expectRevert(abi.encodeWithSelector(InsufficientPosition.selector, 1000000, 483890));
        vault.withdraw(1000000);

        vm.stopPrank();
    }

    function test_CannotAccessRewardsFromWhenPending() public {
        // Approve tokens to be used. We need to startPrank as we rotate through child
        // implementations with this.
        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vm.stopPrank();

        vm.startPrank(PUNK_HOLDER_2);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vm.stopPrank();

        // Make a deposit from User A
        vm.startPrank(PUNK_HOLDER);
        uint depositA = vault.deposit(0.25 ether);
        vm.stopPrank();

        // Move User A deposit from pending to active
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Make a deposit from User B
        vm.startPrank(PUNK_HOLDER_2);
        uint depositB = vault.deposit(0.25 ether);
        vm.stopPrank();

        // Add rewards for the xToken via the vault
        vm.startPrank(address(vault));
        xToken.distributeRewards(100 ether);
        vm.stopPrank();

        // Make another deposit from User A
        vm.startPrank(PUNK_HOLDER);
        uint depositC = vault.deposit(0.25 ether);
        vm.stopPrank();

        // Move User A and B deposits from pending to active
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Confirm that only User A has rewards that can be claimed and that it
        // only requires the amount of the initial deposit.

        // Unfortunately, due to magnitude implications, we don't have an exact 100
        // tokens at this point, but instead may fall 1 wei short. For this reason,
        // our test expects Greater Than 99.99 ether.
        assertGt(xToken.dividendOf(PUNK_HOLDER), 99.99 ether);
        assertEq(xToken.dividendOf(PUNK_HOLDER_2), 0);
        assertGt(xToken.accumulativeRewardOf(PUNK_HOLDER), 99.99 ether);
        assertEq(xToken.accumulativeRewardOf(PUNK_HOLDER_2), 0);

        assertEq(vault.share(PUNK_HOLDER), 6666);
        assertEq(vault.share(PUNK_HOLDER_2), 3333);
        assertEq(vault.position(PUNK_HOLDER), depositA + depositC);
        assertEq(vault.position(PUNK_HOLDER_2), depositB);
    }

    /**
     * We need to make sure that as multiple users deposit into our vault, that we
     * continue to calculate the position and share values correctly.
     */
    function test_ShareCalculation() public {
        address ALT_USER = 0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD;
        address LATE_USER = 0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB;

        // Make a deposit across different holders
        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vault.deposit(100000);
        vm.stopPrank();

        vm.startPrank(ALT_USER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vault.deposit(200000);
        vm.stopPrank();

        // Before recalculation, our depositting users should only hold pending positions
        assertEq(vault.share(PUNK_HOLDER), 0);
        assertEq(vault.share(ALT_USER), 0);
        assertEq(vault.share(LATE_USER), 0);

        assertEq(vault.position(PUNK_HOLDER), 0);
        assertEq(vault.position(ALT_USER), 0);
        assertEq(vault.position(LATE_USER), 0);

        assertEq(vault.pendingPositions(PUNK_HOLDER), 96778);
        assertEq(vault.pendingPositions(ALT_USER), 193556);
        assertEq(vault.pendingPositions(LATE_USER), 0);

        // Recalculate our pending positions into actual positions
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Confirm our shares and positions are returned as expected
        assertEq(vault.share(PUNK_HOLDER), 3333);
        assertEq(vault.share(ALT_USER), 6666);
        assertEq(vault.share(LATE_USER), 0);

        assertEq(vault.position(PUNK_HOLDER), 96778);
        assertEq(vault.position(ALT_USER), 193556);
        assertEq(vault.position(LATE_USER), 0);

        assertEq(vault.pendingPositions(PUNK_HOLDER), 0);
        assertEq(vault.pendingPositions(ALT_USER), 0);
        assertEq(vault.pendingPositions(LATE_USER), 0);

        // Make another deposit from a new user to confirm it is recalculated
        vm.startPrank(LATE_USER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vault.deposit(300000);
        vm.stopPrank();

        // Recalculate our pending positions into actual positions
        vaultFactory.migratePendingDeposits(vault.vaultId());

        // Confirm our shares and positions are returned as expected
        assertEq(vault.share(PUNK_HOLDER), 1666);
        assertEq(vault.share(ALT_USER), 3333);
        assertEq(vault.share(LATE_USER), 5000);

        assertEq(vault.position(PUNK_HOLDER), 96778);
        assertEq(vault.position(ALT_USER), 193556);
        assertEq(vault.position(LATE_USER), 290334);

        // To pass the deposit lock we need to manipulate the block timestamp to set
        // it after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Withdraw fullyfrom one of the user positions
        vm.startPrank(ALT_USER);
        vault.withdraw(193556);
        vm.stopPrank();

        // Confirm our shares and positions are returned as expected
        assertEq(vault.share(PUNK_HOLDER), 2500);
        assertEq(vault.share(ALT_USER), 0);
        assertEq(vault.share(LATE_USER), 7500);

        assertEq(vault.position(PUNK_HOLDER), 96778);
        assertEq(vault.position(ALT_USER), 0);
        assertEq(vault.position(LATE_USER), 290334);

        assertEq(vault.pendingPositions(PUNK_HOLDER), 0);
        assertEq(vault.pendingPositions(ALT_USER), 0);
        assertEq(vault.pendingPositions(LATE_USER), 0);
    }

    function test_CanPause() public {
        assertEq(vault.paused(), false);

        vaultFactory.pause(vault.vaultId(), true);
        assertEq(vault.paused(), true);

        vaultFactory.pause(vault.vaultId(), false);
        assertEq(vault.paused(), false);
    }

    function test_CannotDepositWhenPaused() public {
        vaultFactory.pause(vault.vaultId(), true);
        assertEq(vault.paused(), true);

        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        vm.expectRevert(VaultIsPaused.selector);
        vault.deposit(100000);

        vm.stopPrank();
    }

    /**
     * We cannot expect revert, as this bugs
     */
    function test_CannotPauseWithoutPermissions() public {
        uint vaultId = vault.vaultId();

        vm.startPrank(PUNK_HOLDER);
        vm.expectRevert(
            abi.encodeWithSelector(AccountDoesNotHaveRole.selector, PUNK_HOLDER, authorityControl.VAULT_MANAGER())
        );
        vaultFactory.pause(vaultId, true);
        vm.stopPrank();
    }
}
