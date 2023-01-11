// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../src/contracts/authorities/AuthorityRegistry.sol';
import '../../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import '../../src/contracts/vaults/Vault.sol';

import '../../src/interfaces/strategies/BaseStrategy.sol';

import '../utilities/Environments.sol';


contract VaultTest is FloorTest {

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_075_930;

    /// Reference our vault through our tests
    IBaseStrategy strategy;
    Vault vault;

    /// A wallet that holds PUNK token at the block
    address private constant PUNK_HOLDER = 0x0E239772E3BbfD125E7a9558ccb93D34946caD18;
    uint private constant PUNK_BALANCE = 676000177241559782;

    constructor () forkBlock(BLOCK_NUMBER) {}

    /**
     * Our set up logic creates a valid {Vault} instance that we will
     * subsequently test against.
     */
    function setUp() public {
        // Set up an inventory staking strategy
        strategy = new NFTXInventoryStakingStrategy(bytes32('PUNK'), address(authorityRegistry));

        // Set up our Vault with authority
        vault = new Vault(address(authorityRegistry));
        vault.initialize(
            'Test Vault',                                // Vault Name
            2,                                           // Vault ID
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A,  // Collection: PUNK token
            address(strategy),                           // Strategy: PUNK
            address(0)                                   // VaultFactory: NULL
        );

        strategy.initialize(
            0,               // Vault ID
            address(vault),  // Vault Address
            abi.encode(
                0x269616D549D7e8Eaa82DFb17028d0B212D11232A,  // _pool
                0x269616D549D7e8Eaa82DFb17028d0B212D11232A,  // _underlyingToken
                0x08765C76C758Da951DC73D3a8863B34752Dd76FB,  // _yieldToken
                0x3E135c3E981fAe3383A5aE0d323860a34CfAB893,  // _inventoryStaking
                0x3E135c3E981fAe3383A5aE0d323860a34CfAB893   // _treasury
            )
        );
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
     * the vault.
     */
    function test_CanGetStrategyAddress() public {
        assertEq(address(vault.strategy()), address(strategy));
    }

    /**
     * This helper function gets the vault factory address of the contract that
     * created the vault.
     */
    function test_CanGetVaultFactoryAddress() public {
        assertEq(vault.vaultFactory(), address(0));
    }

    /**
     * The vault ID attributed when the vault is created will be made available
     * via this helper function call.
     */
    function test_CanGetVaultId() public {
        assertEq(vault.vaultId(), 2);
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

        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        assertEq(vault.positions(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Make a deposit from our user and get back the received number of xTokens. The
        // number of xTokens is the amount allocated to the position, not the deposit
        // amount itself.
        uint receivedAmount = vault.deposit(amount);

        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        assertEq(vault.positions(PUNK_HOLDER), receivedAmount);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        vm.stopPrank();
    }

    /**
     * A user should be able to make multiple subsequent deposits into the
     * contract. The return value should be the cumulative value of all
     * deposits made in the test.
     */
    function test_CanDepositMultipleTimes(uint amount1, uint amount2) public {
        vm.assume(amount1 > 10000 && amount1 < PUNK_BALANCE / 2);
        vm.assume(amount2 > 10000 && amount2 < PUNK_BALANCE / 2);

        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        assertEq(vault.positions(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Make 2 varied size deposits into our user's position. The second deposit will
        // return the cumulative user's position that includes both deposit returns.
        uint receivedAmount1 = vault.deposit(amount1);
        uint receivedAmount2 = vault.deposit(amount2);

        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount1 - amount2);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);

        assertEq(vault.positions(PUNK_HOLDER), receivedAmount1 + receivedAmount2);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        vm.stopPrank();
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
        (bool success, ) = address(vault).call{value: 10 ether}('');
        assertEq(success, false);

        vm.stopPrank();
    }

    /**
     * A sender should be able to withdraw fully from their staked position.
     */
    function test_CanWithdrawPartially(uint amount) public {
        // Prevent our deposit from returning a 0 amount from staking
        vm.assume(amount > 10000);

        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Make a deposit of our full balance. This will return a slightly different
        // amount in xToken terms.
        uint depositAmount = vault.deposit(PUNK_BALANCE);

        // Ensure that our test amount is less that or equal to the amount of xToken
        // received from our deposit.
        vm.assume(amount <= depositAmount);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Process a withdrawal of a partial amount against our position
        uint withdrawalAmount = vault.withdraw(amount);

        // Our holder should now have just the withdrawn amount back in their wallet
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), withdrawalAmount);

        // There will be dust left in the strategy and vault
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // The holders position should be their entire balance, minus the amount that
        // was withdrawn. This will still leave our holder with a 100% vault share.
        assertEq(vault.positions(PUNK_HOLDER), depositAmount - amount);
        assertEq(vault.share(PUNK_HOLDER), 10000);

        vm.stopPrank();
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

        console.log(PUNK_BALANCE);
        console.log(amount);
        console.log(depositAmount);
        console.log(withdrawalAmount);
        console.log(vault.positions(PUNK_HOLDER));

        // We need to take our base balance, minus the dust lost during the deposit
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), PUNK_BALANCE - amount + withdrawalAmount);

        // There will be dust left in the strategy and vault
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // Our user should hold no position or share
        assertEq(vault.positions(PUNK_HOLDER), 0);
        assertEq(vault.share(PUNK_HOLDER), 0);

        vm.stopPrank();
    }

    /**
     * A sender should be able to make multiple withdrawal calls.
     */
    function test_CanWithdrawMultipleTimes(uint amount) public {
        // Prevent our deposit from returning a 0 amount from staking
        vm.assume(amount > 10000);

        // Connect to an account that has PUNK tokens
        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // Deposit enough to make sufficiently make 2 withdrawals of our fuzzy value
        uint depositAmount = vault.deposit(PUNK_BALANCE);
        vm.assume(amount < depositAmount / 2);

        // To pass this lock we need to manipulate the block timestamp to set it
        // after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Process 2 vault withdrawals
        uint withdrawalAmount1 = vault.withdraw(amount);
        uint withdrawalAmount2 = vault.withdraw(amount);

        // Our user should now have the twice withdrawn amount in their balance
        assertEq(IERC20(vault.collection()).balanceOf(PUNK_HOLDER), withdrawalAmount1 + withdrawalAmount2);

        // Vault and Strategy dust
        assertEq(IERC20(vault.collection()).balanceOf(address(vault)), 0);
        assertEq(IERC20(vault.collection()).balanceOf(address(strategy)), 0);

        // Our user's remaining position should be calculated by the amount deposited,
        // minus the amount withdrawn (done twice).
        assertEq(vault.positions(PUNK_HOLDER), depositAmount - amount - amount);

        // Since we left at least some dust in the position, we can assert that the
        // holder as 100% of the share.
        assertEq(vault.share(PUNK_HOLDER), 10000);

        vm.stopPrank();
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
        vm.expectRevert('Insufficient position');
        vault.withdraw(1000000);

        vm.stopPrank();
    }

    /**
     * We need to make sure that as multiple users deposit into our vault, that we
     * continue to calculate the position and share values correctly.
     */
    function test_ShareCalculation() public {
        // Make a deposit across three different holders
        vm.startPrank(0x0E239772E3BbfD125E7a9558ccb93D34946caD18);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vault.deposit(100000);
        vm.stopPrank();

        vm.startPrank(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vault.deposit(200000);
        vm.stopPrank();

        // Confirm our shares and positions are returned as expected
        assertEq(vault.share(0x0E239772E3BbfD125E7a9558ccb93D34946caD18), 3333);
        assertEq(vault.share(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD), 6666);
        assertEq(vault.share(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB), 0);

        assertEq(vault.positions(0x0E239772E3BbfD125E7a9558ccb93D34946caD18), 96778);
        assertEq(vault.positions(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD), 193556);
        assertEq(vault.positions(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB), 0);

        // Make another deposit from a new user to confirm it is recalculated
        vm.startPrank(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);
        vault.deposit(300000);
        vm.stopPrank();

        // Confirm our shares and positions are returned as expected
        assertEq(vault.share(0x0E239772E3BbfD125E7a9558ccb93D34946caD18), 1666);
        assertEq(vault.share(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD), 3333);
        assertEq(vault.share(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB), 5000);

        assertEq(vault.positions(0x0E239772E3BbfD125E7a9558ccb93D34946caD18), 96778);
        assertEq(vault.positions(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD), 193556);
        assertEq(vault.positions(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB), 290334);

        // To pass the deposit lock we need to manipulate the block timestamp to set
        // it after our lock would have expired.
        vm.warp(block.timestamp + 10 days);

        // Withdraw fullyfrom one of the user positions
        vm.prank(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD);
        vault.withdraw(193556);

        // Confirm our shares and positions are returned as expected
        assertEq(vault.share(0x0E239772E3BbfD125E7a9558ccb93D34946caD18), 2500);
        assertEq(vault.share(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD), 0);
        assertEq(vault.share(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB), 7500);

        assertEq(vault.positions(0x0E239772E3BbfD125E7a9558ccb93D34946caD18), 96778);
        assertEq(vault.positions(0x069C3cB6EeA06cEf1B70Dc8e0A691F3a1C2789aD), 0);
        assertEq(vault.positions(0x408D22eA33555CadaF9BA59e070Cf6f3Dc3Fd3cB), 290334);
    }

    function test_CanPause() public {
        // Give our test contract the role to manage vaults
        authorityRegistry.grantRole(authorityControl.VAULT_MANAGER(), utilities.deployer());

        assertEq(vault.paused(), false);

        vault.pause(true);
        assertEq(vault.paused(), true);

        vault.pause(false);
        assertEq(vault.paused(), false);
    }

    function test_CannotDepositWhenPaused() public {
        vault.pause(true);
        assertEq(vault.paused(), true);

        vm.startPrank(PUNK_HOLDER);
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        vm.expectRevert('Vault is currently paused');
        vault.deposit(100000);

        vm.stopPrank();
    }

    function test_CannotPauseWithoutPermissions() public {
        vm.prank(PUNK_HOLDER);
        vm.expectRevert('Account does not have role');
        vault.pause(true);
    }

}
