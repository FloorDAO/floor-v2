#!/bin/bash

# Directory path containing the .sol files
cd ../deployment

# Find all .sol files in the directory and sort them alphabetically
files=$(find . -maxdepth 1 -type f -name "*.s.sol" | sort)

# Set chain
chainId="5"
rpcUrl="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9"

# If verifying
verify="" # "--verify"

# Iterate over each file and run the command line script
for file in $files; do
  className=$(echo "$file" | sed 's/^.\{6\}//;s/.\{6\}$//')

  echo "Running script against file: $file:$className"
  forge script ${file:2}:${className} --broadcast $verify --chain-id=$chainId --rpc-url="$rpcUrl" --optimize --optimizer-runs=200
done

'''
forge script 101_DeployAuthorityRegistry.s.sol:DeployAuthorityRegistry --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 102_DeployFloorToken.s.sol:DeployFloorToken --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 104_DeployCollectionRegistry.s.sol:DeployCollectionRegistry --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 105_DeployTreasuryContract.s.sol:DeployTreasuryContract --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 106_DeployStrategyContracts.s.sol:DeployStrategyContracts --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 107_DeployCoreContracts.s.sol:DeployCoreContracts --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 108_DeployFloorWarsContracts.s.sol:DeployFloorWarsContracts --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 110_DeployEpochManager.s.sol:DeployEpochManager --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 111_DeployEpochTriggers.s.sol:DeployEpochTriggers --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 112_DeployLiquidationEpochTrigger.s.sol:DeployLiquidationEpochTriggers --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 113_DeployTreasuryMigration.s.sol:DeployTreasuryMigration --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script 114_AddContractPermissions.s.sol:AddContractPermissions --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200

# forge script 000_MockErc721Contracts.s.sol:DeployErc721Mock --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
# forge script 000_ApproveCollection.s.sol:ApproveCollection --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200

forge script 000_PopulateContractsEvents.s.sol:ApproveCollection --broadcast --chain-id=5 --rpc-url="https://eth-goerli.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
'''
