// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

/**
 * Provides additional logic and helper methods for deployment scripts.
 */
contract DeploymentScript is Script {
    /**
     * Defines the JSON structure used to store contract deployment information.
     *
     * @param deploymentAddress The address that the contract was last deployed to
     * @param key The contract name, or reference key, assigned to the deployment
     */
    struct Deployment {
        address deploymentAddress;
        string key;
    }

    /// Set our JSON storage path
    string constant JSON_PATH = 'script/deployment/deployment-addresses.json';

    /// Set our deployment WETH address
    // Mainnet: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    // Goerli: 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
    // Sepolia: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    /**
     * Ensures that a contract has been deployed already and returns the address of
     * the latest deployed contract.
     *
     * @dev If the requested `key` has not been deployed, then the call will be
     * reverted.
     *
     * @param key The key assigned to the deployed contract
     *
     * @return The address of the deployed contract
     */
    function requireDeployment(string memory key) internal view returns (address payable) {
        // Try to store our deployment address
        address deploymentAddress = getDeployment(key);

        // Ensure we found a deployment address and return it if we did
        require(deploymentAddress != address(0), 'Contract has not been deployed');
        return payable(deploymentAddress);
    }

    /**
     * Gets the stored deployment address. If none is present then a zero address
     * will be returned
     *
     * @param key The key assigned to the deployed contract
     *
     * @return The address of the deployed contract
     */
    function getDeployment(string memory key) internal view returns (address payable) {
        // @dev This will raise an error if it cannot be read
        bytes memory deploymentData = vm.parseJson(vm.readFile(JSON_PATH), '.deployments');
        Deployment[] memory deployments = abi.decode(deploymentData, (Deployment[]));

        // Try to store our deployment address
        address deploymentAddress;

        // Loop through all current deployments to search for our key
        for (uint i; i < deployments.length; ++i) {
            if (keccak256(abi.encodePacked(deployments[i].key)) == keccak256(abi.encodePacked(key))) {
                deploymentAddress = deployments[i].deploymentAddress;
                break;
            }
        }

        return payable(deploymentAddress);
    }

    /**
     * Stores a deployed address against a key.
     *
     * @param key The key assigned to the deployed address
     * @param deploymentAddress The address that the contract was deployed to
     */
    function storeDeployment(string memory key, address deploymentAddress) internal {
        // Ensure we aren't trying to store a zero address
        require(deploymentAddress != address(0), 'Cannot store zero address');

        // Load our current JSON object
        bytes memory deploymentData = vm.parseJson(vm.readFile(JSON_PATH), '.deployments');
        Deployment[] memory deployments = abi.decode(deploymentData, (Deployment[]));

        // Create our new deployments structure
        Deployment[] memory newDeployments = new Deployment[](deployments.length + 1);

        // Check if the key already exists by looping through and overwriting if found
        bool exists;

        // Loop through all current deployments to search for our key
        for (uint i; i < deployments.length; ++i) {
            // Copy over our base data
            newDeployments[i] = deployments[i];

            if (keccak256(abi.encodePacked(deployments[i].key)) == keccak256(abi.encodePacked(key))) {
                deployments[i].deploymentAddress = deploymentAddress;
                exists = true;
            }
        }

        // Register our new deployment data
        if (!exists) {
            newDeployments[newDeployments.length - 1] = Deployment({key: key, deploymentAddress: deploymentAddress});
        } else {
            newDeployments = deployments;
        }

        // Loop through our new deployment data and parse it into a JSON string
        string memory json = '{"deployments":[';
        for (uint k; k < newDeployments.length; ++k) {
            json = string.concat(json, '{"deploymentAddress":"');
            json = string.concat(json, _addressToString(newDeployments[k].deploymentAddress));
            json = string.concat(json, '","key":"');
            json = string.concat(json, newDeployments[k].key);
            json = string.concat(json, '"}');

            if (k + 1 != newDeployments.length) {
                json = string.concat(json, ',');
            }
        }

        json = string.concat(json, ']}');

        // Write the deployed addresses back to our JSON file
        vm.writeFile(JSON_PATH, json);
    }

    /**
     * Wraps around a deployment function to load in the seed phrase of a wallet for
     * deployments.
     */
    modifier deployer() {
        // Load our seed phrase from a protected file
        uint privateKey = vm.envUint('PRIVATE_KEY');

        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast(privateKey);

        _;

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }

    /**
     * Converts an address into a string representation of the address. This allows us
     * to concatenate it against an existing string to write to JSON.
     *
     * @param _address The raw address
     *
     * @return string The address in string format
     */
    function _addressToString(address _address) internal pure returns (string memory) {
        bytes32 _bytes = bytes32(uint(uint160(_address)));
        bytes memory HEX = '0123456789abcdef';
        bytes memory _string = new bytes(42);
        _string[0] = '0';
        _string[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            _string[2 + i * 2] = HEX[uint8(_bytes[i + 12] >> 4)];
            _string[3 + i * 2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
        }

        return string(_string);
    }
}
