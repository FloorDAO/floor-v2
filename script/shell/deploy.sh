#!/bin/bash

# Directory path containing the .sol files
cd ../deployment

# Find all .sol files in the directory and sort them alphabetically
files=$(find . -maxdepth 1 -type f -name "*.s.sol" | sort)

# Set chain
chainId="11155111"
rpcUrl="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9"

# If verifying
verify="" # "--verify"

# Iterate over each file and run the command line script
for file in $files; do
  className=$(echo "$file" | sed 's/^.\{6\}//;s/.\{6\}$//')

  echo "Running script against file: $file:$className"
  forge script ${file:2}:${className} --broadcast $verify --chain-id=$chainId --rpc-url="$rpcUrl" --optimize --optimizer-runs=200
done

'''
forge script script/deployment/101_DeployAuthorityRegistry.s.sol:DeployAuthorityRegistry --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/102_DeployFloorToken.s.sol:DeployFloorToken --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
# forge script script/deployment/103_DeployFloorNft.s.sol:DeployFloorNft --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/104_DeployCollectionRegistry.s.sol:DeployCollectionRegistry --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/105_DeployTreasuryContract.s.sol:DeployTreasuryContract --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/106_DeployStrategyContracts.s.sol:DeployStrategyContracts --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/107_DeployCoreContracts.s.sol:DeployCoreContracts --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/108_DeployFloorWarsContracts.s.sol:DeployFloorWarsContracts --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/110_DeployEpochManager.s.sol:DeployEpochManager --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/111_DeployEpochTriggers.s.sol:DeployEpochTriggers --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200

forge script script/deployment/000_ApproveCollection.s.sol:ApproveCollection --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200

forge script script/deployment/112_DeployLiquidationEpochTriggers.s.sol:DeployLiquidationEpochTriggers --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/113_DeployTreasuryMigration.s.sol:DeployTreasuryMigration --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/114_AddContractPermissions.s.sol:AddContractPermissions --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/115_ApproveSweepers.s.sol:ApproveSweepers --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
forge script script/deployment/116_DeployNFTXV3Strategies.s.sol:DeployNFTXV3Strategies --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200

forge script script/deployment/200_SetSampleSize.s.sol:SetSampleSize --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200

forge script script/deployment/000_EndEpoch.s.sol:EndEpoch --broadcast --chain-id=11155111 --rpc-url="https://eth-sepolia.g.alchemy.com/v2/CCP2hUmJJ6AOwDmyJLmTXuIfetOPcpZ9" --optimize --optimizer-runs=200
'''
