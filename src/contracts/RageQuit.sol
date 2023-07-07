// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';

/**
 * Allows tokens to be deposited into the contract and FLOOR to be burned against it
 * to redeem a share of the assets within the contract. This share is based on the total
 * supply of floor tokens in the ecosystem at point of deployment (no more should be
 * minted) against the total number of tokens deployed into the contract.
 */
contract RageQuit is Ownable, Pausable {
    /// Emitted when funds are added to the contract
    event FundsAdded(address token, uint amount);

    /// Emitted when someone ragequits
    event Paperboy(address paperboy, uint ngmi);

    /// FLOOR token to be accepted to be burnt
    FLOOR public floor;

    /// Store an iterable list of token addresses that are distributed when
    /// someone ragequits.
    address[] private _tokens;

    /// Store the total supply of tokens that we have available for claim
    mapping (address => uint) public tokenSupply;

    /**
     * Defines our FLOOR token that will be burnt for rage quitting.
     *
     * @param _floor The FLOOR token address that will be burnt
     */
    constructor(address _floor) {
        // Register our FLOOR token and capture the total supply
        floor = FLOOR(_floor);
        tokenSupply[_floor] = floor.totalSupply();

        // Start our contract paused
        _pause();
    }

    /**
     * Adds tokens to our contract that will be redeemed against when a user burns floor.
     *
     * @param token The token address used for funding
     * @param amount The amount of token to be transferred into the funding
     */
    function fund(address token, uint amount) public onlyOwner whenPaused {
        // Ensure that an amount supply has been set
        require(amount != 0, 'No supply');

        // Transfer the approved token into this contract
        ERC20(token).transferFrom(msg.sender, address(this), amount);

        // Increase the total supply held in the contract
        tokenSupply[token] += amount;

        // Check if the token needs adding to our tokens array
        bool found;
        for (uint i; i < _tokens.length;) {
            if (_tokens[i] == token) {
                found = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!found) {
            _tokens.push(token);
        }

        // Confirm that funds have been added via event
        emit FundsAdded(token, amount);
    }

    /**
     * Burns FLOOR tokens from the user in exchange for receipt of funding tokens to the
     * same value.
     *
     * @param amount The amount of FLOOR tokens to transfer from the message sender
     */
    function ragequit(uint amount) public whenNotPaused {
        // Ensure that an amount is passed
        require(amount != 0, 'No tokens burnt');

        // Burn the floor from the caller
        floor.burnFrom(msg.sender, amount);

        // Iterate over all funding tokens and distribue a share of them to the caller
        uint tokenCount = _tokens.length;
        uint decimalDifference;

        for (uint i; i < tokenCount;) {
            // Determine the decimal difference
            decimalDifference = 1 ** (ERC20(_tokens[i]).decimals() - 9);

            ERC20(_tokens[i]).transfer(
                msg.sender,
                (amount * decimalDifference * tokenSupply[_tokens[i]]) / (tokenSupply[address(floor)] * decimalDifference)
            );

            unchecked {
                ++i;
            }
        }

        // Goodbye, old friend.
        emit Paperboy(msg.sender, amount);
    }

    /**
     * Exits all tokens from the contract so that we can either refill, or shutdown the
     * process.
     *
     * @dev This function can only be called when the contract is paused.
     */
    function rescue() public onlyOwner whenPaused {
        // Loop through all funding tokens and extract them to caller
        uint tokenCount = _tokens.length;
        for (uint i; i < tokenCount;) {
            ERC20(_tokens[i]).transfer(msg.sender, ERC20(_tokens[i]).balanceOf(address(this)));
            tokenSupply[_tokens[i]] = 0;
            unchecked {
                ++i;
            }
        }

        // Remove our tokens array so we can start fresh next time
        delete _tokens;
    }

    /**
     * Allows our contract to be unpaused when it is ready to be used. This action is
     * not reversable and fully decentralises the contract.
     */
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    /**
     * Returns the array of tokens that are currently funding the contract.
     *
     * @return address[] An array of funding token addresses
     */
    function tokens() public view returns (address[] memory) {
        return _tokens;
    }
}
