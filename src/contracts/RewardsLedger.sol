// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import './authorities/AuthorityControl.sol';

import '../interfaces/staking/VeFloorStaking.sol';
import '../interfaces/tokens/Floor.sol';
import '../interfaces/RewardsLedger.sol';
import '../interfaces/Treasury.sol';

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

    // Maintains a mapping of available token amounts by recipient
    mapping(address => mapping(address => uint)) internal allocations;

    // Maintains a mapping of claimed token amounts by recipient
    mapping(address => mapping(address => uint)) public claimed;

    // Maintain a list of token addresses that the recipient has either currently, or
    // previously, had an allocation of. This allows us to iterate mappings.
    mapping(address => address[]) internal tokens;
    mapping(address => mapping(address => bool)) internal tokenStore;

    // Allow the claim logic to be paused
    bool public paused;

    /**
     * Set up our connection to the Treasury to ensure future calls only come from this
     * trusted source.
     */
    constructor(address _authority, address _floor, address _staking, address _treasury) AuthorityControl(_authority) {
        floor = IFLOOR(_floor);
        staking = IVeFloorStaking(_staking);
        treasury = _treasury;
    }

    /**
     * Allocate a set amount of a specific token to be accessible by the recipient. The token
     * amount won't actually be transferred to the {RewardsLedger}, but will instead just notify
     * us of the allocation and it will be transferred from the {Treasury} directly to the user
     * at point of claim.
     *
     * This can only be called by an approved caller.
     */
    function allocate(address recipient, address token, uint amount)
        external
        onlyRole(REWARDS_MANAGER)
        returns (uint)
    {
        // We don't want to allow NULL address allocation
        require(token != address(0), 'Invalid token');

        // Prevent zero values being allocated and wasting gas
        require(amount != 0, 'Invalid amount');

        // Allocate the token amount to recipient token
        allocations[recipient][token] += amount;

        // If this is a token that the user has not previously been allocated, then
        // we can add it to the user's list of tokens.
        if (!tokenStore[recipient][token]) {
            tokens[recipient].push(token);
            tokenStore[recipient][token] = true;
        }

        // Fire our allocation event
        emit RewardsAllocated(recipient, token, amount);

        // Return the user's total allocation for the token
        return allocations[recipient][token];
    }

    /**
     * Get the amount of available token for the recipient.
     */
    function available(address recipient, address token) external view returns (uint) {
        return allocations[recipient][token];
    }

    /**
     * Get all tokens available to the recipient, as well as the amounts of each token.
     */
    function availableTokens(address recipient) external view returns (address[] memory, uint[] memory) {
        uint length = tokens[recipient].length;
        address[] memory tokens_ = new address[](length);
        uint[] memory amounts_ = new uint[](length);

        for (uint i; i < tokens[recipient].length;) {
            tokens_[i] = tokens[recipient][i];
            amounts_[i] = allocations[recipient][tokens[recipient][i]];

            unchecked {
                ++i;
            }
        }

        return (tokens_, amounts_);
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

        // If the user is claiming floor token it will need to be minted from
        // the {Treasury}, as opposed to just being transferred.
        if (token == address(floor)) {
            // First we send the floor token to the recipient, as the staking contract will take
            // the tokens from the origin caller, not the contract that calls it.
            floor.approve(address(staking), amount);

            // Stake the tokens into the {VeFloorStaking} contract
            staking.depositFor(amount, msg.sender);
        } else {
            // Transfer the tokens from the {Treasury} to the recipient
            ITreasury(treasury).withdrawERC20(msg.sender, token, amount);
        }

        // Fire a message for our stalkers
        emit RewardsClaimed(msg.sender, token, amount);

        // Return the total amount claimed
        return claimed[msg.sender][token];
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
