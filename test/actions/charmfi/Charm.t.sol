// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {AlphaVault} from '@charmfi/contracts/AlphaVault.sol';

import {CharmCreateVault} from '@floor/actions/charmfi/CreateVault.sol';
import {CharmDeposit} from '@floor/actions/charmfi/Deposit.sol';
import {CharmRebalance} from '@floor/actions/charmfi/Rebalance.sol';
import {CharmWithdraw} from '@floor/actions/charmfi/Withdraw.sol';

import {FloorTest} from '../../utilities/Environments.sol';

contract CharmFinanceVaultTest is FloorTest {
    // Store our action contracts
    CharmCreateVault charmCreateVault;
    CharmDeposit charmDeposit;
    CharmRebalance charmRebalance;
    CharmWithdraw charmWithdraw;

    constructor() forkBlock(17_094_248) {
        // Send this address as the {Treasury} parameter so we can see what comes back
        charmCreateVault = new CharmCreateVault();
        charmDeposit = new CharmDeposit();
        charmRebalance = new CharmRebalance();
        charmWithdraw = new CharmWithdraw();
    }

    /**
     * Confirm that we can swap an approved amount of token with sufficient balance
     * and receive back the expected amount of WETH into the {Treasury}.
     */
    function test_CanCreateVaultAndPerformUserJourney() public {
        // Create a vault. This copies the contract creation values of the existing
        // WETH - USDC vault.
        uint vaultAddressUint = charmCreateVault.execute(
            abi.encode(
                // Vault parameters
                2000000000000000000, // maxTotalSupply
                0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8, // uniswapPool
                uint24(5000), // protocolFee
                // Strategy parameters
                int24(3600), // baseThreshold
                int24(1200), // limitThreshold
                int24(0), // minTickMove
                uint40(41400), // period
                int24(100), // maxTwapDeviation
                uint32(60), // twapDuration
                address(charmRebalance) // keeper
            )
        );

        // Convert our created vault address uint representation into an address
        address vaultAddress = address(uint160(vaultAddressUint));

        // Confirm our created vault address. This will be newly deployed, but in
        // this test scenario it is deterministic.
        assertEq(vaultAddress, 0x5B0091f49210e7B2A57B03dfE1AB9D08289d9294);

        // We need to supply our test contract with sufficient funds to place the
        // deposit.
        deal(address(AlphaVault(vaultAddress).token0()), address(this), 100 ether);
        deal(address(AlphaVault(vaultAddress).token1()), address(this), 100 ether);

        // Confirm that our user has received the expected token amounts
        assertEq(AlphaVault(vaultAddress).token0().balanceOf(address(this)), 100 ether);
        assertEq(AlphaVault(vaultAddress).token1().balanceOf(address(this)), 100 ether);

        // Approve our token to be deposited
        AlphaVault(vaultAddress).token0().approve(address(charmDeposit), 100 ether);
        AlphaVault(vaultAddress).token1().approve(address(charmDeposit), 100 ether);

        // Deposit into the vault
        uint shares = charmDeposit.execute(
            abi.encode(
                200000000, // amount0Desired
                100000000000000000, // amount1Desired
                180000000, // amount0Min
                90000000000000000, // amount1Min
                vaultAddress // vault
            )
        );

        // Confirm the number of shares that we received. We should hold 100% of the
        // vault share as it is newly created.
        assertEq(shares, 100000000000000000);

        // Get our strategy address used for our rebalancing call
        address strategyAddress = AlphaVault(vaultAddress).strategy();

        // Confirm our strategy address. This will be newly deployed, but in this test
        // scenario it is deterministic.
        assertEq(strategyAddress, 0xDD4c722d1614128933d6DC7EFA50A6913e804E12);

        // Rebalance the vault
        charmRebalance.execute(abi.encode(strategyAddress));

        // Approve our withdraw action to burn our shares
        AlphaVault(vaultAddress).approve(address(charmWithdraw), shares);

        // Withdraw from the vault
        charmWithdraw.execute(
            abi.encode(
                shares, // shares
                0, // amount0Min
                0, // amount1Min
                vaultAddress // vault
            )
        );

        // Confirm the amount of tokens received back from our withdrawal
    }

    function test_CanDepositAndWithdrawFromExistingVault() public {
        // Convert our created vault address uint representation into an address
        address vaultAddress = 0x9bF7B46C7aD5ab62034e9349Ab912C0345164322;

        // We need to supply our test contract with sufficient funds to place the
        // deposit.
        deal(address(AlphaVault(vaultAddress).token0()), address(this), 100 ether);
        deal(address(AlphaVault(vaultAddress).token1()), address(this), 100 ether);

        // Approve our token to be deposited
        AlphaVault(vaultAddress).token0().approve(address(charmDeposit), 100 ether);
        AlphaVault(vaultAddress).token1().approve(address(charmDeposit), 100 ether);

        // Deposit into the vault
        uint shares = charmDeposit.execute(
            abi.encode(
                200000000, // amount0Desired
                100000000000000000, // amount1Desired
                0, // amount0Min
                0, // amount1Min
                vaultAddress // vault
            )
        );

        // Confirm the number of shares that we received
        assertEq(shares, 75925179422139150);

        // Approve our withdraw action to burn our shares
        AlphaVault(vaultAddress).approve(address(charmWithdraw), shares);

        // Withdraw from the vault
        charmWithdraw.execute(
            abi.encode(
                shares, // shares
                0, // amount0Min
                0, // amount1Min
                vaultAddress // vault
            )
        );
    }
}
