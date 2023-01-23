// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import './authorities/AuthorityControl.sol';
import './tokens/VaultXToken.sol';

import '../interfaces/staking/VeFloorStaking.sol';
import '../interfaces/tokens/Floor.sol';
import '../interfaces/vaults/Vault.sol';
import '../interfaces/vaults/VaultFactory.sol';
import '../interfaces/RewardsLedger.sol';
import '../interfaces/Treasury.sol';

import "forge-std/console.sol";

/**
 * The rewards ledger holds all available rewards available to be claimed
 * by FLOOR users, as well as keeping a simple ledger of all tokens already
 * claimed.
 *
 * The {RewardsLedger} will have the ability to transfer assets from {Treasury}
 * to recipient as it sees fit, whilst providing some separation of concerns.
 *
 * Used the X2Y2 Drop contract as a starting point:
 * https://etherscan.io/address/0xe6949137b24ad50cce2cf6b124b3b874449a41fa#readContract
 */
contract RewardsLedger is AuthorityControl, IRewardsLedger {
    // Addresses of our internal contracts, assigned in the constructor
    IFLOOR public immutable floor;
    IVeFloorStaking public staking;
    address public immutable treasury;
    IVaultFactory public immutable vaultFactory;

    // Maintains a mapping of available token amounts by recipient
    mapping(address => mapping(address => uint)) internal allocations;

    // Maintains a mapping of claimed token amounts by recipient
    mapping(address => mapping(address => uint)) public claimed;

    // Allow the claim logic to be paused
    bool public paused;

    /**
     * Set up our connection to the Treasury to ensure future calls only come from this
     * trusted source.
     */
    constructor(address _authority, address _floor, address _staking, address _treasury, address _vaultFactory) AuthorityControl(_authority) {
        floor = IFLOOR(_floor);
        staking = IVeFloorStaking(_staking);
        treasury = _treasury;
        vaultFactory = IVaultFactory(_vaultFactory);
    }

    /**
     * Allocate a set amount of a specific token to be accessible by the recipient. The token
     * amount won't actually be transferred to the {RewardsLedger}, but will instead just notify
     * us of the allocation and it will be transferred from the {Treasury} directly to the user
     * at point of claim.
     *
     * This can only be called by an approved caller.
     */
    function allocate(address recipient, address token, uint amount) external onlyRole(REWARDS_MANAGER) returns (uint) {
        // We don't want to allow NULL address allocation
        require(token != address(0), 'Invalid token');

        // Prevent zero values being allocated and wasting gas
        require(amount != 0, 'Invalid amount');

        // Allocate the token amount to recipient token
        allocations[recipient][token] += amount;

        // Fire our allocation event
        emit RewardsAllocated(recipient, token, amount);

        // Return the user's total allocation for the token
        return allocations[recipient][token];
    }

    /**
     * Get the amount of available token for the recipient.
     */
    function available(address recipient, address token) external view returns (uint) {
        // TODO: If the user is looking at floor, we should also compute what is available
        // from across their staked vaults.
        return allocations[recipient][token];
    }

    /**
     * These tokens are stored in the {Treasury}, but will be allowed access from
     * this contract to allow them to be claimed at a later time.
     *
     * A user will be able to claim the token as long as the {Treasury} holds
     * the respective token (which it always should) and has sufficient balance
     * in `available`.
     *
     * If the user is claiming FLOOR token from the {Treasury}, then it will need
     * to call the `mint` function as the {Treasury} won't hold it already.
     */
    function claim(address token, uint amount) external returns (uint) {
        // Ensure that we haven't paused claims
        require(!paused, 'Claiming currently paused');

        // Ensure that we aren't sending up a zero value for claim
        require(amount != 0, 'Invalid amount');

        // Ensure that the recipient has sufficient allocation of the requested token
        require(allocations[msg.sender][token] >= amount, 'Insufficient allocation');

        // Decrement our recipients allocation before actioning the transfer to avoid
        // reentrancy issues.
        allocations[msg.sender][token] -= amount;

        // We can increment the amount of claimed token
        claimed[msg.sender][token] += amount;

        // Transfer the tokens from the {Treasury} to the recipient
        ITreasury(treasury).withdrawERC20(msg.sender, token, amount);

        // Fire a message for our stalkers
        emit RewardsClaimed(msg.sender, token, amount);

        // Return the total amount claimed
        return claimed[msg.sender][token];
    }

    function claimFloor() public returns (uint) {
        console.log('A');
        // Get start balance
        uint startBalance = floor.balanceOf(msg.sender);
        console.log('B');
        // Iterate the vaults and claim until we have reached our limit
        address[] memory vaults = vaultFactory.vaults();
        for (uint i; i < vaults.length;) {
            console.log('C');
            VaultXToken(IVault(vaults[i]).xToken()).withdrawReward(msg.sender);
            console.log('D');
            unchecked { ++i; }
        }

        console.log('E');
        return floor.balanceOf(msg.sender) - startBalance;
    }

    function availableFloor(address user) public returns (uint available_) {
        address[] memory vaults = vaultFactory.vaults();

        // Iterate the vaults and sum the total dividend amounts
        for (uint i; i < vaults.length;) {
            available_ += VaultXToken(IVault(vaults[i]).xToken()).dividendOf(user);
            unchecked { ++i; }
        }
    }

    /**
     * Allows our governance to pause rewards being claimed. This should be used
     * if an issue is found in the code causing incorrect rewards being distributed,
     * until a fix can be put in place.
     */
    function pause(bool _paused) external onlyAdminRole {
        paused = _paused;
        emit RewardsPaused(_paused);
    }

}
