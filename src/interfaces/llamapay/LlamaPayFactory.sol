//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

interface ILlamaPayFactory {
    function INIT_CODEHASH() external returns (bytes32);
    function parameter() external returns (address);
    function getLlamaPayContractCount() external returns (uint);
    function getLlamaPayContractByIndex(uint) external returns (address);

    /**
     * @notice Create a new Llama Pay Streaming instance for `_token`
     *
     * @dev Instances are created deterministically via CREATE2 and duplicate instances
     * will cause a revert.
     *
     * @param _token The ERC20 token address for which a Llama Pay contract should be deployed
     *
     * @return llamaPayContract The address of the newly created Llama Pay contract
     */
    function createLlamaPayContract(address _token) external returns (address llamaPayContract);

    /**
     * @notice Query the address of the Llama Pay contract for `_token` and whether it is deployed
     *
     * @param _token An ERC20 token address
     *
     * @return predictedAddress The deterministic address where the llama pay contract will be deployed for `_token`
     * @return isDeployed Boolean denoting whether the contract is currently deployed
     */
    function getLlamaPayContractByToken(address _token) external view returns (address predictedAddress, bool isDeployed);
}
