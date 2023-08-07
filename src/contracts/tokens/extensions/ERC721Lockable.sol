// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721A} from '@ERC721A/ERC721A.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/**
 * Allows an ERC721 token to be softlocked by an external contract. We piggyback
 * the existing approval logic to allow the external contract to have locking rights.
 *
 * By allowing a token to be softlocked, we can get claim timelocked rewards or
 * benfits without the requirement of transferring the token away from the user.
 *
 * In addition, we also allow for staking contracts to be specified that will allow
 * a user to soft lock their token, without the token being in direct ownership of
 * the calling user. It will, however, require that the
 */
abstract contract ERC721Lockable is ERC721A, Ownable {
    /**
     * Holds information about our token locks.
     */
    struct TokenLock {
        address locker;
        uint96 unlocksAt;
    }

    /// Maps token IDs to locks
    mapping(uint => TokenLock) internal tokenLocks;

    /// Maps token IDs to a user that has it staked in an approved staking contract.
    mapping(uint => address) public heldStakes;

    /// Maps an approved locking address to a token ID.
    mapping(uint => address) public approvedLockers;

    /// List of approved stakers
    address[] public approvedStakers;

    /**
     * Checks if the token ID is currently locked, based on the lock timestamp.
     */
    function isLocked(uint tokenId) public view returns (bool) {
        return tokenLocks[tokenId].unlocksAt > block.timestamp;
    }

    /**
     * The address of the staker that has locked the token ID. If the token is not
     * currently locked, then a zero address will be returned.
     */
    function lockedBy(uint tokenId) public view returns (address) {
        return isLocked(tokenId) ? tokenLocks[tokenId].locker : address(0);
    }

    /**
     * The timestamp that the token is locked until. If the token is not currently
     * locked then `0` will be returned.
     */
    function lockedUntil(uint tokenId) external view returns (uint) {
        return isLocked(tokenId) ? tokenLocks[tokenId].unlocksAt : 0;
    }

    /**
     * Approves an address to lock the token, in the same manner that `approve` works.
     */
    function approveLocker(address to, uint tokenId, bool approve) external {
        address currentOwner = ownerOf(tokenId);
        require(to != currentOwner, 'ERC721A: approval to current owner');

        if (currentOwner != msg.sender && (heldStakes[tokenId] != msg.sender || !_isApprovedStaker(currentOwner))) {
            revert('ERC721A: approve caller is not token owner');
        }

        if (approve) {
            approvedLockers[tokenId] = to;
        } else {
            delete approvedLockers[tokenId];
        }
    }

    /**
     * Revokes an address from locking the token, in the same manner that `approve` works.
     */
    function approveLocker(address to, uint tokenId) external {
        address currentOwner = ownerOf(tokenId);
        require(to != currentOwner, 'ERC721A: approval to current owner');

        if (currentOwner != msg.sender && (heldStakes[tokenId] != msg.sender || !_isApprovedStaker(currentOwner))) {
            revert('ERC721A: approve caller is not token owner');
        }

        approvedLockers[tokenId] = to;
    }

    /**
     * Locks the token ID
     */
    function lock(address user, uint tokenId, uint96 unlocksAt) external {
        require(approvedLockers[tokenId] == msg.sender, 'Locker not approved');

        // Check if the user is either an owner or holds holds the staked token
        address currentOwner = ownerOf(tokenId);
        if (currentOwner != user && (heldStakes[tokenId] != user || !_isApprovedStaker(currentOwner))) {
            revert('User is not owner, nor currently staked with an approved staker');
        }

        // Check if we are already locked
        require(!isLocked(tokenId), 'Token is already locked');

        // Create our lock
        tokenLocks[tokenId] = TokenLock(msg.sender, unlocksAt);
    }

    /**
     * Allows a locker to unlock a token that they currently have locked.
     */
    function unlock(uint tokenId) external {
        // Ensure that the token is locked by the locker calling it
        if (lockedBy(tokenId) == msg.sender) {
            delete tokenLocks[tokenId];
        }
    }

    /**
     * Allows a new staker contract to be approved to lock the token.
     */
    function setApprovedStaker(address staker, bool approved) external onlyOwner {
        bool found;
        uint index;

        // Search our array to find an existing approved staker
        for (uint i; i < approvedStakers.length;) {
            if (staker == approvedStakers[i]) {
                found = true;
                index = i;
            }

            unchecked {
                ++i;
            }
        }

        // Check if we have an incompatible state for the request
        require(approved != found, 'Staker invalid state');

        // If we have approved a token, push it onto our array
        if (approved) {
            approvedStakers.push(staker);
        }
        // If we are removing an approved staker, then we can delete it from the array
        else {
            delete approvedStakers[index];
        }
    }

    /**
     * Before a token is transferred, we need to check if it is being sent to an approved
     * staking contract to maintain.
     */
    function _beforeTokenTransfers(address from, address to, uint firstTokenId, uint batchSize) internal virtual override (ERC721A) {
        // If we are sending the token to an approved staker, then we want to hold ownership
        // against the user that sent it, to allow future softlocking. If the token is already
        // marked as staked by a user, then we maintain the current holder, otherwise we update
        // the staker to the `from` address.
        if (_isApprovedStaker(to)) {
            heldStakes[firstTokenId] = (heldStakes[firstTokenId] == address(0)) ? from : heldStakes[firstTokenId];
        }

        // If we are transferring the token out of an approved staking contract to an address
        // that is not another approved staking contract, then we need to delete the held stake.
        if (!_isApprovedStaker(to)) {
            delete heldStakes[firstTokenId];
        }

        // We can now process the transfer
        super._beforeTokenTransfers(from, to, firstTokenId, batchSize);
    }

    /**
     * Check if an address is present in our approved stakers list.
     */
    function _isApprovedStaker(address staker) internal view returns (bool) {
        for (uint i; i < approvedStakers.length;) {
            if (staker == approvedStakers[i]) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }
}
