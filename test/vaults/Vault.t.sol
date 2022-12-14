// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../src/contracts/vaults/Vault.sol';

import '../utilities/Environments.sol';


contract VaultTest is FloorTest {

    /// Store our mainnet fork information
    uint256 mainnetFork;
    uint internal constant BLOCK_NUMBER = 16_075_930;

    /// Reference our vault through our tests
    Vault vault;

    /// A wallet that holds PUNK token at the block
    address private constant PUNK_HOLDER = 0x0E239772E3BbfD125E7a9558ccb93D34946caD18;

    /**
     * Our set up logic creates a valid {Vault} instance that we will
     * subsequently test against.
     */
    function setUp() public {
        // Generate a mainnet fork
        mainnetFork = vm.createFork(vm.envString('MAINNET_RPC_URL'));

        // Select our fork for the VM
        vm.selectFork(mainnetFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(BLOCK_NUMBER);

        // Confirm that our block number has set successfully
        assertEq(block.number, BLOCK_NUMBER);

        // Set up our Vault
        vault = new Vault(address(0));
        vault.initialize(
            'Test Vault',                                // Vault Name
            0,                                           // Vault ID
            0x269616D549D7e8Eaa82DFb17028d0B212D11232A,  // Collection: PUNK token
            address(0),                                  // Strategy: NULL
            address(0)                                   // VaultFactory: NULL
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
        assertEq(vault.strategy(), address(0));
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
    function test_CanDeposit(uint amount) public {}

    /**
     * A user should be able to make multiple subsequent deposits into the
     * contract. The return value should be the cumulative value of all
     * deposits made in the test.
     */
    function test_CanDepositMultipleTimes(uint amount) public {}

    /**
     * If the sender has not approved their token to be transferred, then
     * we should expect a revert.
     */
    function test_CannotDepositWithoutApproval() public {
        vm.expectRevert();
        vault.deposit(10 ether);
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
        vm.expectRevert();
        vault.deposit(10 ether);

        vm.stopPrank();
    }

    /**
     * If the sender attempts to send a token to the contract outside of
     * the deposit function, then we should revert it. If the token sent
     * is the same as the collection address, then we can be courteous
     * and try to handle it as a legitimate deposit.
     */
    function test_CannotSendTokensOutsideOfDepositCall() public {
        // Attempt to send tokens directly to our contract
        vm.startPrank(PUNK_HOLDER);

        // Approve use of PUNK token
        IERC20(vault.collection()).approve(address(vault), type(uint).max);

        // vm.expectRevert();
        // IERC20(vault.collection()).transfer(address(vault), 10e17);

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
    function testCanWithdrawPartially(uint amount) public {}

    /**
     * A sender should be able to withdraw partially from their staked position.
     */
    function testCanWithdrawFully(uint amount) public {}

    /**
     * A sender should be able to make multiple withdrawal calls.
     */
    function testCanWithdrawMultipleTimes(uint amount) public {}

    /**
     * If a sender does not has a sufficient balance to withdraw from then
     * we should revert the call.
     */
    function testCannotWithdrawWithoutSufficientBalance() public {}

}
