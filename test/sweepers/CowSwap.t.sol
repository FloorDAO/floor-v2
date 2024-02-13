// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import 'forge-std/console.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

import {IConditionalOrder} from '@composable-cow/interfaces/IConditionalOrder.sol';
import {TWAPOrder} from '@composable-cow/types/twap/libraries/TWAPOrder.sol';

import {CowSwapSweeper} from '@floor/sweepers/CowSwap.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract CowSwapSweeperTest is FloorTest {

    uint constant BLOCK_NUMBER = 19176494;

    CowSwapSweeper internal sweeper;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Deploy our authority contracts
        super._deployAuthority();
    }

    function setUp() public {
        // Deploy our sweeper contract
        sweeper = new CowSwapSweeper({
            _authority: address(authorityRegistry),
            _treasury: payable(0x3b91f74Ae890dc97bb83E7b8eDd36D8296902d68),
            _relayer: 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110,
            _composableCow: 0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74,
            _twapHandler: 0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5
        });
    }

    function test_CanExecuteSweep() public {
        // Create our 1 eth order
        _createOrder(1 ether);

        // Store the bytes that were created by the above (extracted from event logging)
        IConditionalOrder.ConditionalOrderParams memory conditionalOrderParams = IConditionalOrder.ConditionalOrderParams({
            handler: IConditionalOrder(0x6cF1e9cA41f7611dEf408122793c358a3d11E5a5),
            salt: 0xc24d8e2aa014479d1f2f121e1e3589ddb390cf3334d1dc8d527cf385c8e8d76d,
            staticInput: hex'000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000003b91f74ae890dc97bb83e7b8edd36d8296902d6800000000000000000000000000000000000000000000000006f05b59d3b200000000000000000000000000000000000000000000000000000000aca00bcf12520000000000000000000000000000000000000000000000000000000065c37fcb000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000151800000000000000000000000000000000000000000000000000000000000000000c24d8e2aa014479d1f2f121e1e3589ddb390cf3334d1dc8d527cf385c8e8d76d'
        });

        // Confirm that the single order exists
        assertTrue(
            sweeper.composableCow().singleOrders(
                address(sweeper),
                sweeper.composableCow().hash(conditionalOrderParams)
            )
        );

        // Confirm that we can get the tradable order with signature
        sweeper.composableCow().getTradeableOrderWithSignature({
            owner: address(sweeper),
            params: conditionalOrderParams,
            offchainInput: bytes(''),
            proof: new bytes32[](0)
        });
    }

    function test_CanWithdrawWeth(uint _withdrawAmount) public {
        // We cannot vary the sellAmount value as we need an expected hash
        uint _wethAmount = 10 ether;

        // Ensure the amount we withdraw is less or equal to the full order amount
        vm.assume(_withdrawAmount <= _wethAmount);

        // Ensure our test contract has enough WETH
        deal(address(this), _wethAmount);

        // Create an order
        _createOrder(_wethAmount);

        // Register the hash of the order, taken from the onchain event fired from this test
        bytes32 orderHash = 0xf436705361ff2a284d04fca9c04c06549cbebd457636629b061b12f6a02db522;

        // Move forward past our unlock time
        (uint192 maxAmount, uint64 unlockTime) = sweeper.swaps(orderHash);
        assertEq(maxAmount, _wethAmount);
        assertEq(unlockTime, 1707397450);
        vm.warp(unlockTime);

        // Confirm that we can withdraw the desired amount
        sweeper.rescueWethFromOrder(orderHash, _withdrawAmount);

        // Confirm that the expected amount is now in the {Treasury} and remaining in the pool
        assertEq(sweeper.weth().balanceOf(address(sweeper)), _wethAmount - _withdrawAmount);
        assertEq(sweeper.weth().balanceOf(sweeper.treasury()), _withdrawAmount);

        // Confirm that we cannot rescue from the same order again
        vm.expectRevert('Invalid order hash');
        sweeper.rescueWethFromOrder(orderHash, _withdrawAmount);
    }

    function test_CannotWithdrawFromUnknownOrderHash() public {
        // Create an order
        _createOrder(10 ether);

        // Register the hash of the order, taken from the onchain event fired from this test
        bytes32 invalidOrderHash = 0xf436705361ff2a284d04fca9c04c06549cbebd457636629b061b12f6a02db521;

        // Confirm that we can withdraw the desired amount
        vm.expectRevert('Invalid order hash');
        sweeper.rescueWethFromOrder(invalidOrderHash, 1 ether);
    }

    function test_CannotWithdrawMoreWethThanAllocated(uint _withdrawAmount) public {
        // We cannot vary the sellAmount value as we need an expected hash
        uint _wethAmount = 10 ether;

        // Ensure the amount we withdraw is MORE than the full order amount
        vm.assume(_withdrawAmount > _wethAmount);

        // Ensure our test contract has enough WETH
        deal(address(this), _wethAmount);

        // Create an order
        _createOrder(_wethAmount);

        // Register the hash of the order, taken from the onchain event fired from this test
        bytes32 orderHash = 0xf436705361ff2a284d04fca9c04c06549cbebd457636629b061b12f6a02db522;

        // Move forward past our unlock time
        (uint192 maxAmount, uint64 unlockTime) = sweeper.swaps(orderHash);
        assertEq(maxAmount, _wethAmount);
        assertEq(unlockTime, 1707397450);
        vm.warp(unlockTime);

        // Confirm that we can withdraw the desired amount
        vm.expectRevert('Withdraw amount too high');
        sweeper.rescueWethFromOrder(orderHash, _withdrawAmount);
    }

    function test_CannotWithdrawWethWithoutPermissions() public {
        // Create an order
        _createOrder(10 ether);

        // Register the hash of the order, taken from the onchain event fired from this test
        bytes32 orderHash = 0xf436705361ff2a284d04fca9c04c06549cbebd457636629b061b12f6a02db522;

        // Move forward past our unlock time
        (uint192 maxAmount, uint64 unlockTime) = sweeper.swaps(orderHash);
        assertEq(maxAmount, 10 ether);
        assertEq(unlockTime, 1707397450);
        vm.warp(unlockTime);

        // Confirm that we can withdraw the desired amount
        vm.startPrank(address(4));
        vm.expectRevert();
        sweeper.rescueWethFromOrder(orderHash, 1 ether);
        vm.stopPrank();
    }

    function test_CannotWithWethBeforeUnlock(uint seed) public {
        // Create an order
        _createOrder(10 ether);

        // Register the hash of the order, taken from the onchain event fired from this test
        bytes32 orderHash = 0xf436705361ff2a284d04fca9c04c06549cbebd457636629b061b12f6a02db522;

        // Move to a time that is before our unlock time
        (uint192 maxAmount, uint64 unlockTime) = sweeper.swaps(orderHash);
        assertEq(maxAmount, 10 ether);
        assertEq(unlockTime, 1707397450);
        vm.warp(bound(seed, block.timestamp, unlockTime - 1));

        // Confirm that we can withdraw the desired amount
        vm.expectRevert('Withdraw not unlocked');
        sweeper.rescueWethFromOrder(orderHash, 1 ether);
    }

    function _createOrder(uint _amount) internal {
        address[] memory collections = new address[](1);
        collections[0] = address(1);
        uint[] memory amounts = new uint[](1);
        amounts[0] = _amount;

        CowSwapSweeper.Pool[] memory pools = new CowSwapSweeper.Pool[](1);
        pools[0] = CowSwapSweeper.Pool({
            pool: 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640,   // Address of the UV3 pool
            fee: 300,          // The UV3 pool fee
            slippage: 10_0,    // % of slippage to 1dp accuracy
            partSize: 1_00     // The ETH size per part for fills (2dp)
        });

        sweeper.execute{value: _amount}({
            _collections: collections,
            _amounts: amounts,
            data: abi.encode(pools)
        });

        // Confirm that we now hold the expected balance in the pool
        assertEq(sweeper.weth().balanceOf(address(sweeper)), _amount);
    }

}

contract CowSwapSweeperSepoliaTest is FloorTest {

    uint constant BLOCK_NUMBER = 5251146;

    CowSwapSweeper internal sweeper;

    constructor() forkSepoliaBlock(BLOCK_NUMBER) {
        // Deploy our sweeper contract
        sweeper = CowSwapSweeper(payable(0x3D85E9127797B546c3C8dE92B58bc7895471d2a6));
    }

    function test_CanGetTradeableOrderWithSignature() public {
        bytes memory _bytes = hex'00000000000000000000000000000000000000000000000000000000000000200000000000000000000000006cf1e9ca41f7611def408122793c358a3d11e5a5c24d8e2aa014479d1f2f121e1e3589ddb390cf3334d1dc8d527cf385c8e8d76d00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000140000000000000000000000000fff9976782d46cc05630d1f6ebab18b2324d6b140000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f9840000000000000000000000003b91f74ae890dc97bb83e7b8edd36d8296902d68000000000000000000000000000000000000000000000000003b363eb8ee951c0000000000000000000000000000000000000000000000000a5a94a9b2efb4cd0000000000000000000000000000000000000000000000000000000065c5fee4000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000151800000000000000000000000000000000000000000000000000000000000000000c24d8e2aa014479d1f2f121e1e3589ddb390cf3334d1dc8d527cf385c8e8d76d';
        IConditionalOrder.ConditionalOrderParams memory conditionalOrderParams = abi.decode(_bytes, (IConditionalOrder.ConditionalOrderParams));

        console.log('HASH:');
        console.logBytes32(sweeper.composableCow().hash(conditionalOrderParams));

        sweeper.composableCow().getTradeableOrderWithSignature({
            owner: 0x3D85E9127797B546c3C8dE92B58bc7895471d2a6,
            params: conditionalOrderParams,
            offchainInput: bytes(''),
            proof: new bytes32[](0)
        });

        bytes memory _staticInput = conditionalOrderParams.staticInput;
        TWAPOrder.Data memory _data = abi.decode(_staticInput, (TWAPOrder.Data));

        console.log(address(_data.sellToken));
        console.log(address(_data.buyToken));
        console.log(_data.receiver);
        console.log(_data.partSellAmount);
        console.log(_data.minPartLimit);
        console.log(_data.t0);
        console.log(_data.n);
        console.log(_data.t);
        console.log(_data.span);
        console.logBytes32(_data.appData);

        TWAPOrder.validate(_data);
    }

}
