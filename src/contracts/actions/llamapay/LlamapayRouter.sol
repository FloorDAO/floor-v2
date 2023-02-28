// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {ILlamaPay} from '@floor-interfaces/llamapay/LlamaPay.sol';
import {ILlamaPayFactory} from '@floor-interfaces/llamapay/LlamaPayFactory.sol';


/**
 * ..
 */
contract LlamapayRouter is Pausable {

    /// ..
    ILlamaPayFactory public immutable llamaPayFactory;

    /// ..
    address public immutable treasury;

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     *
     * @param _llamaPayFactory Address of the LlamaPay Factory contract
     * @param _treasury Address of the Floor {Treasury} contract
     */
    constructor(address _llamaPayFactory, address _treasury) {
        llamaPayFactory = ILlamaPayFactory(_llamaPayFactory);
        treasury = _treasury;
    }

    /**
     * ..
     */
    function createStream(address to, address token, uint amount, uint216 amountPerSec) public returns (uint) {
        // Determine the LlamaPay contract based on the deposit token
        (address predictedAddress, bool isDeployed) = llamaPayFactory.getLlamaPayContractByToken(token);

        // If the token contract doesn't yet exist, then we will need to create it
        if (!isDeployed) {
            llamaPayFactory.createLlamaPayContract(token);
        }

        // Load our LlamaPay pool
        ILlamaPay llamaPay = ILlamaPay(predictedAddress);

        // If we are also depositing tokens, then we handle the fund transfer as a prerequisite
        if (amount != 0) {
            // Transfer tokens from the {Treasury} and approve llamapay to transfer it when needed
            IERC20(token).transferFrom(treasury, address(this), amount);
            IERC20(token).approve(predictedAddress, amount);

            // Deposit the tokens to LlamaPay and create our stream in a single call
            llamaPay.depositAndCreate(amount, to, amountPerSec);
        }
        else {
            // Otherwise, we just create the stream
            llamaPay.createStream(to, amountPerSec);
        }

        // We return the total balance currently held by the action
        return uint(llamaPay.getPayerBalance(address(this)));
    }

    /**
     * ..
     */
    function deposit(address token, uint amount) public returns (uint) {
        // Ensure we aren't trying to deposit a zero amount
        require(amount != 0, 'Cannot deposit zero amount');

        // Get our LlamaPay contract
        ILlamaPay llamaPay = _getLlamapayPool(token);

        // Transfer tokens from the {Treasury} and approve llamapay to transfer it when needed
        IERC20(token).transferFrom(treasury, address(this), amount);
        IERC20(token).approve(address(llamaPay), amount);

        // Deposit our request amount into the token stream
        llamaPay.deposit(amount);

        // We return the total balance currently held by the action
        return uint(llamaPay.getPayerBalance(address(this)));
    }

    /**
     * ..
     */
    function withdraw(address token, uint amount) public returns (uint) {
        // Get our LlamaPay contract
        ILlamaPay llamaPay = _getLlamapayPool(token);

        // If we have sent a zero value, then we withdraw the entire balance
        if (amount == 0) {
            llamaPay.withdrawPayerAll();
            IERC20(token).transfer(treasury, IERC20(token).balanceOf(address(this)));
            return 0;
        }

        // Otherwise, we only withdraw and transfer the specified amount
        llamaPay.withdrawPayer(amount);

        // Transfer tokens back to {Treasury}
        IERC20(token).transfer(treasury, IERC20(token).balanceOf(address(this)));

        // We return the total balance currently held by the action
        return uint(llamaPay.getPayerBalance(address(this)));
    }

    function _getLlamapayPool(address token) internal view returns (ILlamaPay) {
        // Determine the LlamaPay contract based on the deposit token
        (address predictedAddress, bool isDeployed) = llamaPayFactory.getLlamaPayContractByToken(token);
        require(isDeployed, 'LlamaPay token stream does not exist');

        return ILlamaPay(predictedAddress);
    }

}