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
contract LlamapayCreateStream is IAction, Pausable {

    /// ..
    ILlamaPayFactory public immutable llamaPayFactory;

    /// ..
    address public immutable treasury;

    /**
     * Store our required information to action a swap.
     */
    struct ActionRequest {
        address to;
        address token;
        uint216 amountPerSec;
        uint amountToDeposit;
    }

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
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into our struct
        ActionRequest memory request = abi.decode(_request, (ActionRequest));

        // Determine the LlamaPay contract based on the deposit token
        (address predictedAddress, bool isDeployed) = llamaPayFactory.getLlamaPayContractByToken(request.token);

        // If the token contract doesn't yet exist, then we will need to create it
        if (!isDeployed) {
            llamaPayFactory.createLlamaPayContract(request.token);
        }

        // If we are also depositing tokens, then we handle the fund transfer as a prerequisite
        if (request.amountToDeposit != 0) {
            // Transfer tokens from the {Treasury} and approve llamapay to transfer it when needed
            IERC20(request.token).transferFrom(treasury, address(this), request.amountToDeposit);
            IERC20(request.token).approve(predictedAddress, request.amountToDeposit);

            // Deposit the tokens to LlamaPay and create our stream in a single call
            ILlamaPay(predictedAddress).depositAndCreate(request.amountToDeposit, request.to, request.amountPerSec);
        }
        else {
            // Otherwise, we just create the stream
            ILlamaPay(predictedAddress).createStream(request.to, request.amountPerSec);
        }

        // We return the total balance currently held by the action
        return uint(ILlamaPay(predictedAddress).getPayerBalance(address(this)));
    }

}
