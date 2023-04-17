// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';


contract DeploymentScript is Script {

    struct Deployment {
        address deploymentAddress;
        string key;
    }

    string constant JSON_PATH = 'script/deployment/deployment-addresses.json';

    function requireDeployment(string memory key) internal returns (address) {
        // @dev This will raise an error if it cannot be read
        bytes memory deploymentData = vm.parseJson(vm.readFile(JSON_PATH), 'deployments');
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

        // Ensure we found a deployment address and return it if we did
        require(deploymentAddress != address(0), 'Contract has not been deployed');
        return deploymentAddress;
    }

    function storeDeployment(string memory key, address deploymentAddress) internal {
        // Load our current JSON object
        bytes memory deploymentData = vm.parseJson(vm.readFile(JSON_PATH), 'deployments');
        Deployment[] memory deployments = abi.decode(deploymentData, (Deployment[]));

        // Create our new deployments structure
        Deployment[] memory newDeployments = new Deployment[](deployments.length + 1);

        // Check if the key already exists by looping through and overwriting if found
        bool exists;

        // Loop through all current deployments to search for our key
        for (uint i; i < deployments.length; ++i) {
            if (keccak256(abi.encodePacked(deployments[i].key)) == keccak256(abi.encodePacked(key))) {
                deployments[i].deploymentAddress = deploymentAddress;
                exists = true;
                break;
            }
        }

        // Register our new deployment data
        if (!exists) {
            newDeployments[newDeployments.length - 1] = Deployment({
                key: key,
                deploymentAddress: deploymentAddress
            });
        } else {
            newDeployments = deployments;
        }

        // Loop through our new deployment data and parse it into a JSON string
        string memory json = '{"deployments":[';
        for (uint k; k < newDeployments.length; ++k) {
            json = string.concat(json, '{"deploymentAddress":"');
            json = string.concat(json, _addressToString(newDeployments[k].deploymentAddress));
            json = string.concat(json, '","key":"');
            json = string.concat(json, key);
            json = string.concat(json, '"}');

            if (k + 1 != newDeployments.length) {
                json = string.concat(json, ',');
            }
        }

        json = string.concat(json, ']}');

        console.logString(json);

        vm.writeFile(JSON_PATH, json);

        console.log('Contract has been added to JSON successfully');
    }

    function _addressToString(address _address) internal pure returns(string memory) {
       bytes32 _bytes = bytes32(uint256(uint160(_address)));
       bytes memory HEX = "0123456789abcdef";
       bytes memory _string = new bytes(42);
       _string[0] = '0';
       _string[1] = 'x';
       for(uint i = 0; i < 20; i++) {
           _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
           _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
       }

       return string(_string);
    }

    modifier deployer() {
        // Load our seed phrase from a protected file
        string memory seedPhrase = vm.readFile('.seedphrase');
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);

        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast(privateKey);

        _;

        // Stop collecting onchain transactions
        vm.stopBroadcast();
    }

}
