// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

import {FLOOR} from '@floor/tokens/Floor.sol';

/**
 * Allows tokens to be deposited into the contract and FLOOR to be burned against it
 * to redeem a share of the assets within the contract.
 *
 * For example, if you deposit $400 worth of tokens, this will be mapped to a TVL value
 * that may be around $700. The user will then receive a value the equivalent of this
 * TVL value.
 *
 * Each funding token that is offered in the contract must maintain the same value when
 * multipled by the amount. For example, if 100eth of xPUNK token is added, then the same
 * 100eth value of WETH must be added, and the same is true of all subsequent tokens.
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
    address[] internal _tokens;

    /// Maps the value of a token to ETH value
    mapping(address => uint) public tokenValue;

    /**
     * Defines our FLOOR token that will be burnt for rage quitting.
     *
     * @param _floor The FLOOR token address that will be burnt
     */
    constructor(address _floor) {
        floor = FLOOR(_floor);
    }

    /**
     * Adds tokens to our contract and sets the value. The value of the funding token
     * will be used in the calculation of the FLOOR <-> funding token conversion, so it
     * is important that all token values are taken from the same block for provable
     * faireness.
     *
     * @dev Value should be set in terms of ETH for a single token. If just the token
     * value wants to be updated without funding additional tokens, then a zero `amount`
     * can be passed.
     *
     * @param token The token address used for funding
     * @param amount The amount of token to be transferred into the funding
     * @param value The ETH value of a single token
     */
    function fund(address token, uint amount, uint value) public onlyOwner {
        // Transfer the approved token into this contract
        if (amount != 0) {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }

        // Assign our token value in ETH terms
        tokenValue[token] = value;

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
     * Allows the TVL FLOOR value to be updated.
     *
     * @dev This should be set in ETH terms.
     *
     * @param _floorValue ETH value of a single FLOOR token
     */
    function setFloorValue(uint _floorValue) public onlyOwner {
        tokenValue[address(floor)] = _floorValue;
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
        for (uint i; i < tokenCount;) {
            IERC20(_tokens[i]).transfer(msg.sender, ((tokenValue[address(floor)] * amount) / tokenValue[_tokens[i]]) / tokenCount);

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
            IERC20(_tokens[i]).transfer(msg.sender, IERC20(_tokens[i]).balanceOf(address(this)));
            unchecked {
                ++i;
            }
        }

        // Remove our tokens array so we can start fresh next time
        delete _tokens;
    }

    /**
     * Allows our contract to be paused or unpaused. When paused this will stop rage quits
     * from taking place and will allow for the `rescue` function to be called.
     *
     * @param _paused If the contract should be paused, or unpaused
     */
    function pause(bool _paused) public onlyOwner {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
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
