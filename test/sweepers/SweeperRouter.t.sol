// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {SweeperRouter} from '@floor/sweepers/SweeperRouter.sol';
import {SudoswapSweeper} from '@floor/sweepers/Sudoswap.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

import {TreasuryMock} from '../mocks/TreasuryMock.sol';
import {FloorTest} from '../utilities/Environments.sol';

contract SweeperRouterTest is FloorTest {

    /// An event fired when a collection sweeper is updated
    event CollectionSweeperUpdated(address _collection, address _sweeper, bytes _data);

    /// Define our internal contracts
    SweeperRouter internal router;
    TreasuryMock internal treasury;

    /// Define some approved sweepers
    address APPROVED_SWEEPER_ONE;
    address APPROVED_SWEEPER_TWO;

    /// Define an unapproved sweeper that will revert
    address UNAPPROVED_SWEEPER = address(2);

    function setUp() public {
        treasury = new TreasuryMock();
        router = new SweeperRouter(payable(address(treasury)));

        // Deploy our sweeper contract
        APPROVED_SWEEPER_ONE = address(new ManualSweeper());
        APPROVED_SWEEPER_TWO = address(new ManualSweeper());

        // Approve our sweepers
        treasury.approveSweeper(APPROVED_SWEEPER_ONE, true);
        treasury.approveSweeper(APPROVED_SWEEPER_TWO, true);

        // Ensure that our unapproved sweeper is unapproved
        treasury.approveSweeper(UNAPPROVED_SWEEPER, false);
    }

    function test_CanCheckNoPermissionsRequired() public {
        assertEq(router.permissions(), '');
    }

    function test_CannotDeployWithInvalidTreasury() public {
        vm.expectRevert();
        router = new SweeperRouter(payable(address(0)));
    }

    function test_CanExecuteWithSameSweeper(uint8 _collections, bytes calldata _bytes) public {
        // Only test with 1-5 collections, as this is a realistic sample size
        uint collectionsLength = bound(_collections, 1, 5);

        // Keep track of the total require amount
        uint totalAmount;

        // Set up our collections array and define our amounts
        address[] memory collections = new address[](collectionsLength);
        uint[] memory amounts = new uint[](collectionsLength);
        for (uint i = 0; i < collectionsLength; ++i) {
            collections[i] = payable(address(uint160(i + 1)));  // Avoid a zero address
            amounts[i] = (i + 1) * 1 ether;  // Avoid a zero amount

            // Increment our total amount required
            totalAmount += amounts[i];

            // Map our collection to the sweeper
            router.setSweeper(collections[i], APPROVED_SWEEPER_ONE, 'MANUAL');
        }

        // Execute our router
        router.execute{value: totalAmount}(collections, amounts, _bytes);
    }

    function test_CanExecuteWithMultipleSweepers() public {
        // Set up our collections array and define our amounts
        address[] memory collections = new address[](3);
        collections[0] = payable(address(1));
        collections[1] = payable(address(2));
        collections[2] = payable(address(3));

        uint[] memory amounts = new uint[](3);
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        amounts[2] = 3 ether;

        // Map our collection to the sweeper
        router.setSweeper(collections[0], APPROVED_SWEEPER_ONE, 'ONE');
        router.setSweeper(collections[1], APPROVED_SWEEPER_TWO, 'TWO');
        router.setSweeper(collections[2], APPROVED_SWEEPER_ONE, 'THREE');

        // Execute our router
        router.execute{value: 6 ether}(collections, amounts, '');
    }

    function test_CannotExecuteWithInsufficentMsgValue(uint _reductionSeed) public {
        uint collectionsLength = 1;
        uint totalAmount;

        // Set up our collections array and define our amounts
        address[] memory collections = new address[](collectionsLength);
        uint[] memory amounts = new uint[](collectionsLength);
        for (uint i = 0; i < collectionsLength; ++i) {
            collections[i] = payable(address(uint160(i + 1)));  // Avoid a zero address
            amounts[i] = (i + 1) * 1 ether;  // Avoid a zero amount

            // Increment our total amount required
            totalAmount += amounts[i];

            // Map our collection to the sweeper
            router.setSweeper(collections[i], APPROVED_SWEEPER_ONE, 'MANUAL');
        }

        // Execute our router, with a random number less that the total amount
        uint reduction = bound(_reductionSeed, 1, totalAmount);

        vm.expectRevert();
        router.execute{value: totalAmount - reduction}(collections, amounts, '');
    }

    function test_CannotExecuteWithUnassignedSweeper(address _collection) public {
        // Set up our array parameters with a zero amounts value to prevent the requirement
        // of sending ETH.
        address[] memory collections = new address[](1);
        collections[0] = _collection;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 0;

        // Try and run the router against the collection we have specified
        vm.expectRevert('Sweeper contract not approved');
        router.execute(collections, amounts, '');
    }

    function test_CannotExecuteWithUnapprovedSweeper(address _collection) public {
        // Assign an unapproved sweeper to the collection
        router.setSweeper(_collection, UNAPPROVED_SWEEPER, '');

        // Set up our array parameters with a zero amounts value to prevent the requirement
        // of sending ETH.
        address[] memory collections = new address[](1);
        collections[0] = _collection;
        uint[] memory amounts = new uint[](1);
        amounts[0] = 0;

        // Try and run the router against the collection we have specified
        vm.expectRevert('Sweeper contract not approved');
        router.execute(collections, amounts, '');
    }

    function test_CanSetSweeper(address _collection, address _sweeper, bytes calldata _data) public {
        // Confirm that before the sweeper is set, we have empty information
        (ISweeper sweeper, bytes memory data) = router.collectionSweepers(_collection);
        assertEq(address(sweeper), address(0));
        assertEq(data, '');

        // Ensure that we have an event emitted
        vm.expectEmit(true, true, false, true, address(router));
        emit CollectionSweeperUpdated(_collection, _sweeper, _data);

        // Create our sweeper
        router.setSweeper(_collection, _sweeper, _data);

        // Load our sweeper
        (sweeper, data) = router.collectionSweepers(_collection);

        // Confirm that our information is correct
        assertEq(address(sweeper), _sweeper);
        assertEq(data, _data);
    }

    function test_CannotSetSweeperIfNotOwner(address _caller, address _collection, address _sweeper, bytes calldata _data) public {
        // Ensure that the caller is not the owner
        vm.assume(_caller != address(this));

        // We expect our call to revert as we are not the owner
        vm.startPrank(_caller);
        vm.expectRevert();
        router.setSweeper(_collection, _sweeper, _data);
        vm.stopPrank();
    }

}
