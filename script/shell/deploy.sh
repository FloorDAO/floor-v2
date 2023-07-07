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
