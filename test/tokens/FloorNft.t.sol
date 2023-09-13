// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {FloorNft} from '@floor/tokens/FloorNft.sol';

import {FloorTest} from '../utilities/Environments.sol';

contract FloorNftTest is FloorTest, IERC721Receiver {
    // Store some test users
    address alice;
    address bob;
    address validStaker;
    address locker;

    // Reference our Floor token contract
    FloorNft floorNft;

    constructor() {
        // Deploy our Floor NFT contract
        floorNft = new FloorNft(
            'Floor NFT',  // _name
            'nftFloor',   // _symbol
            250,          // _maxSupply
            5             // _maxMintAmountPerTx
        );

        // The majority of our tests will use, or rely on, the default minting
        // approach. So for the purpose of the majority of tests we will, by
        // default, pause minting. These can be enabled again for specific tests.
        floorNft.setPaused(false);

        // Set some of our test users
        (alice, bob, validStaker, locker) = (users[0], users[1], users[2], users[3]);

        // Set up our staker user as an approved staker
        floorNft.setApprovedStaker(validStaker, true);
    }

    /**
     * Base ERC721 Specific Tests
     */

    function test_CanMint() public {
        // Try and mint one (1)
        floorNft.mint{value: 0.05 ether}(1);

        // Try and mint against the max supply (5)
        floorNft.mint{value: 0.25 ether}(floorNft.maxMintAmountPerTx());
    }

    function test_CanMintToMaxSupply() public {
        floorNft.setMaxSupply(2);
        floorNft.mint{value: 0.1 ether}(2);
    }

    function test_CannotMintWithInsufficientFunds() public {
        vm.expectRevert('Insufficient funds');
        floorNft.mint{value: 0.01 ether}(1);
    }

    function test_CannotMintAboveMaxSupply() public {
        floorNft.setMaxSupply(2);

        vm.expectRevert('Max supply exceeded');
        floorNft.mint{value: 1 ether}(3);
    }

    function test_CannotMintAboveMaxTransactionSize() public {
        uint maxAmount = floorNft.maxMintAmountPerTx();

        vm.expectRevert('Invalid mint amount');
        floorNft.mint{value: 1 ether}(maxAmount + 1);
    }

    function test_CannotMintWhenPaused() public {
        floorNft.setPaused(true);

        vm.expectRevert('The contract is paused');
        floorNft.mint{value: 0.05 ether}(1);
    }

    function test_CanWhitelistMint() public {
        // Set our Merkle tree that has our Alice address added, but not Bob :(
        floorNft.setMerkleRoot(hex'e9444147f02cc757d548f09d59c1486c68143c744a7b8d58bffeef39c6259a8f');

        vm.startPrank(alice);
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11065',
                    hex'259d2aa12da7bc2037a7ccbee4dfac71ae56c2436cbbc918d8a29d98c51a488e',
                    hex'79cbfa017bce7e8fcd50afc8d762a758ca9d1836f38d433da5503d1c4bcb898b',
                    hex'c580fc92ea18e6d170b1b05e0d812075c6e945c64493edede0cab8f0c4a89c2f'
                ]
            )
        );
        vm.stopPrank();

        // Try and mint with Bob
        vm.startPrank(bob);
        vm.expectRevert('Invalid proof');
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'6336b8bb274032aa3be701ac6a1d53b59751cb189032350fca009329bdacf405',
                    hex'eb32294b145a6cb39a8253090debc4d56632d1c2df9c90c9f6df5021cd5f09bb',
                    hex'84bf0a7cc18a5896163ba81bd983480c37b0c99123c17a977974daa016db39f1',
                    hex'59d753adc1377ab6343d2b715bcfac8108e7f170e7bab164a015bc82a86ac642'
                ]
            )
        );
        vm.stopPrank();

        // Try and mint again with Alice
        vm.startPrank(alice);
        vm.expectRevert('Address has already claimed');
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11065',
                    hex'259d2aa12da7bc2037a7ccbee4dfac71ae56c2436cbbc918d8a29d98c51a488e',
                    hex'79cbfa017bce7e8fcd50afc8d762a758ca9d1836f38d433da5503d1c4bcb898b',
                    hex'c580fc92ea18e6d170b1b05e0d812075c6e945c64493edede0cab8f0c4a89c2f'
                ]
            )
        );
        vm.stopPrank();

        // Update our Merkle to one that supports Bob, but not Alice
        floorNft.setMerkleRoot(hex'3e895d9cf21c50ba4ede4bc83f3c479925830060f23c8402544e3802dc7c2e87');

        // Try and mint as Alice. Even though the proof will be invalid, it will show
        // that the address has already claimed.
        vm.startPrank(alice);
        vm.expectRevert('Address has already claimed');
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'6336b8bb274032aa3be701ac6a1d53b59751cb189032350fca009329bdacf404',
                    hex'6a0a5fd2600a000cf6b68f978ef1663a0738da6d7b3a1fae4b2b1ff5b6def37c',
                    hex'0a2d04dd5ef25cb74db4bd9771bbadc4ac405123083bba87fec44300dafbcb0d',
                    hex'd1afeb55fd702313cff2cfedfe81063cb9af4ab270081f9bf3be6934cca00ab2'
                ]
            )
        );
        vm.stopPrank();

        // We could now mint as Bob, but for the test we will update the Merkle
        // one last time so we can additionally prove that Alice cannot mint twice,
        // even after a Merkle update.

        // Bob AND Alice
        floorNft.setMerkleRoot(hex'4121c56ef1d4bf420366e5ba431017d621e768f85cd6dc3423548e92cea8e094');

        // Try and mint as Alice
        vm.startPrank(alice);
        vm.expectRevert('Address has already claimed');
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'6336b8bb274032aa3be701ac6a1d53b59751cb189032350fca009329bdacf405',
                    hex'81da62a48687a95c0f8e542a968839e157dad1dfc115674386ed95e06019adce',
                    hex'0f36e286880e6aef8e46cd0cd5929279fc265b847042c5f5fb78af068f21dd4e',
                    hex'39e4c466dc63ec62e9adbfcae524ef61fd985a0e3efc644fc1adad465eef5925'
                ]
            )
        );
        vm.stopPrank();

        // Try and mint as Bob
        vm.startPrank(bob);
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064',
                    hex'81da62a48687a95c0f8e542a968839e157dad1dfc115674386ed95e06019adce',
                    hex'0f36e286880e6aef8e46cd0cd5929279fc265b847042c5f5fb78af068f21dd4e',
                    hex'39e4c466dc63ec62e9adbfcae524ef61fd985a0e3efc644fc1adad465eef5925'
                ]
            )
        );
        vm.stopPrank();

        // Try and mint again as Bob
        vm.startPrank(bob);
        vm.expectRevert('Address has already claimed');
        floorNft.whitelistMint(
            _setBytesArray(
                [
                    hex'972a69aadb9fb2dd5e3d4936ac6c01ebf152fc475a5f13a2ba0c5cf039d11064',
                    hex'81da62a48687a95c0f8e542a968839e157dad1dfc115674386ed95e06019adce',
                    hex'0f36e286880e6aef8e46cd0cd5929279fc265b847042c5f5fb78af068f21dd4e',
                    hex'39e4c466dc63ec62e9adbfcae524ef61fd985a0e3efc644fc1adad465eef5925'
                ]
            )
        );
        vm.stopPrank();
    }

    function test_CannotWhitelistMintWithoutValidMerkleAccess() public {
        // Tested in `test_CanWhitelistMint`
    }

    function test_CannotWhitelistMintMultipleTimes() public {
        // Tested in `test_CanWhitelistMint`
    }

    function test_CanUpdateMaxSupply() public {
        assertEq(floorNft.maxSupply(), 250);
        floorNft.setMaxSupply(1000);
        assertEq(floorNft.maxSupply(), 1000);
    }

    function test_CanSetMaxMintAmountPerTx() public {
        assertEq(floorNft.maxMintAmountPerTx(), 5);
        floorNft.setMaxMintAmountPerTx(8);
        assertEq(floorNft.maxMintAmountPerTx(), 8);
    }

    function test_CanSetUri() public {
        floorNft.mint{value: 0.05 ether}(1);

        floorNft.setUri('https://nft.nftx.io/');
        assertEq(floorNft.tokenURI(0), 'https://nft.nftx.io/0');

        floorNft.setUri('https://nft.floor.xyz/');
        assertEq(floorNft.tokenURI(0), 'https://nft.floor.xyz/0');
    }

    function test_CanSetPaused() public {
        assertEq(floorNft.paused(), 2);
        floorNft.setPaused(true);
        assertEq(floorNft.paused(), 1);
        floorNft.setPaused(false);
        assertEq(floorNft.paused(), 2);
    }

    function test_CanWithdrawFundsFromContract() public {
        floorNft.mint{value: 0.25 ether}(5);
        assertEq(address(floorNft).balance, 0.25 ether);

        uint startBalance = address(this).balance;

        floorNft.withdraw();

        assertEq(address(floorNft).balance, 0 ether);
        assertEq(address(this).balance, startBalance + 0.25 ether);
    }

    function test_CannotWithdrawFundsFromContractWithoutOwner() public {
        vm.startPrank(alice);
        vm.expectRevert('Ownable: caller is not the owner');
        floorNft.withdraw();
        vm.stopPrank();
    }

    /**
     * ERC721Lockable Specific Tests
     */

    function test_CanLockWhenOwnedByUser() public {
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        vm.prank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        assertEq(floorNft.isLocked(0), true);
        assertEq(floorNft.lockedBy(0), locker);
        assertEq(floorNft.lockedUntil(0), uint96(block.timestamp + 3600));
        assertEq(floorNft.heldStakes(0), address(0));

        vm.warp(uint96(block.timestamp + 3600));

        assertEq(floorNft.isLocked(0), false);
        assertEq(floorNft.lockedBy(0), address(0));
        assertEq(floorNft.lockedUntil(0), 0);
        assertEq(floorNft.heldStakes(0), address(0));
    }

    function test_CanLockWhenStakedWithApprovedContract() public {
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);

        // Transfer the NFT to our approved staking contract
        floorNft.transferFrom(alice, validStaker, 0);

        // Approve our locker
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // We can now lock the NFT as alice, even though it is in the staking contract. We
        // should get the same output as our locking as if it was owned by the user.
        vm.prank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        assertEq(floorNft.isLocked(0), true);
        assertEq(floorNft.lockedBy(0), locker);
        assertEq(floorNft.lockedUntil(0), uint96(block.timestamp + 3600));
        assertEq(floorNft.heldStakes(0), alice);

        vm.warp(uint96(block.timestamp + 3600));

        assertEq(floorNft.isLocked(0), false);
        assertEq(floorNft.lockedBy(0), address(0));
        assertEq(floorNft.lockedUntil(0), 0);
        assertEq(floorNft.heldStakes(0), alice);
    }

    function test_CannotLockWhenAlreadyLocked() public {
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);

        // Transfer the NFT to our approved staking contract
        floorNft.transferFrom(alice, validStaker, 0);

        // Approve our locker
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // We can now lock the NFT as alice, even though it is in the staking contract. We
        // should get the same output as our locking as if it was owned by the user.
        vm.startPrank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        vm.expectRevert('Token is already locked');
        floorNft.lock(alice, 0, uint96(block.timestamp + 7200));
        vm.stopPrank();
    }

    function test_CannotLockTokenWithoutApprovingLocker() public {
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);

        // Transfer the NFT to our approved staking contract
        floorNft.transferFrom(alice, validStaker, 0);
        vm.stopPrank();

        // We can now lock the NFT as alice, even though it is in the staking contract. We
        // should get the same output as our locking as if it was owned by the user.
        vm.prank(locker);
        vm.expectRevert('Locker not approved');
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));
    }

    function test_CannotLockWhenTokenNotOwnedOrStaked() public {
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.transferFrom(alice, validStaker, 0);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // The token cannot be locked on behalf of Bob, when approved by Alice
        vm.prank(locker);
        vm.expectRevert('User is not owner, nor currently staked with an approved staker');
        floorNft.lock(bob, 0, uint96(block.timestamp + 3600));
    }

    function test_CanUnlock() public {
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.transferFrom(alice, validStaker, 0);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // The token cannot be locked on behalf of Bob, when approved by Alice
        vm.prank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        assertEq(floorNft.isLocked(0), true);

        vm.prank(locker);
        floorNft.unlock(0);

        assertEq(floorNft.isLocked(0), false);
        assertEq(floorNft.lockedBy(0), address(0));
        assertEq(floorNft.lockedUntil(0), 0);
        assertEq(floorNft.heldStakes(0), alice);
    }

    function test_CannotUnlockIfNotCurrentlyOwnedByCaller() public {
        // Mint the NFT and approve the locker, but don't lock the NFT
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.transferFrom(alice, validStaker, 0);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        vm.prank(locker);
        floorNft.unlock(0);
    }

    function test_CanDeleteHeldStakeOnTransferBackToOriginalOwner() public {
        // Mint the NFT and approve the locker, but don't lock the NFT
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.transferFrom(alice, validStaker, 0);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // ..
        vm.prank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        assertEq(floorNft.heldStakes(0), alice);

        vm.prank(validStaker);
        floorNft.transferFrom(validStaker, alice, 0);

        assertEq(floorNft.heldStakes(0), address(0));
    }

    function test_CanPersistStakeOnTransferToApprovedContract() public {
        // Mint the NFT and approve the locker, but don't lock the NFT
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.transferFrom(alice, validStaker, 0);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // ..
        vm.prank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        assertEq(floorNft.heldStakes(0), alice);

        // Set Bob to be a secondary approved staker
        floorNft.setApprovedStaker(bob, true);

        vm.prank(validStaker);
        floorNft.transferFrom(validStaker, bob, 0);

        assertEq(floorNft.heldStakes(0), alice);
    }

    function test_CanDeleteStakeOnTransferToUnpprovedContract() public {
        // Mint the NFT and approve the locker, but don't lock the NFT
        vm.startPrank(alice);
        floorNft.mint{value: 0.05 ether}(1);
        floorNft.transferFrom(alice, validStaker, 0);
        floorNft.approveLocker(locker, 0, true);
        vm.stopPrank();

        // ..
        vm.prank(locker);
        floorNft.lock(alice, 0, uint96(block.timestamp + 3600));

        assertEq(floorNft.heldStakes(0), alice);

        vm.prank(validStaker);
        floorNft.transferFrom(validStaker, bob, 0);

        assertEq(floorNft.heldStakes(0), address(0));
    }

    function test_CanSetApprovedStaker() public {
        // We start with a single approved staker, so the 0 address will return it
        assertEq(floorNft.approvedStakers(0), validStaker);

        // The first index will not return an address as none set
        vm.expectRevert();
        floorNft.approvedStakers(1);

        // Set our new approved staker
        floorNft.setApprovedStaker(bob, true);
        assertEq(floorNft.approvedStakers(1), bob);
    }

    function test_CanRemoveApprovedStaker() public {
        // We start with a single approved staker, so the 0 address will return it
        assertEq(floorNft.approvedStakers(0), validStaker);

        // Remove our valid staker
        floorNft.setApprovedStaker(validStaker, false);
        assertEq(floorNft.approvedStakers(0), address(0));
    }

    function test_CannotApproveStakerThatIsAlreadyApproved() public {
        vm.expectRevert('Staker invalid state');
        floorNft.setApprovedStaker(validStaker, true);
    }

    function test_CannotRemoveApprovedStakerThatIsNotApproved() public {
        vm.expectRevert('Staker invalid state');
        floorNft.setApprovedStaker(bob, false);
    }

    function onERC721Received(address, address, uint, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    function _setBytesArray(string[4] memory input) internal pure returns (bytes32[] memory) {
        bytes32[] memory arr = new bytes32[](input.length);
        for (uint i; i < input.length; ++i) {
            arr[i] = bytes32(abi.encodePacked(input[i]));
        }
        return arr;
    }
}
