# Floor

Version 2 of Floor aims to drive as much ETH as possible to the Floor Wars each week. It also takes a step to decentralise the processes by bringing sweep accountability onchain.


## What are the goals of Floor?

Floor aims to create a fully onchain governance mechanism for sweeping and deploying NFTs to profitable NFT-Fi strategies as well as seeding liquidity for its own NFT-Fi products.

The DAO's NFT-Fi strategies (and any future products) will generate yield for the DAO, which feeds back into the protocol’s NFT sweeping mechanism.

FLOOR token holders will have ultimate control over what collections are swept every week, imbuing the FLOOR token with voting power that can be traded for yield on vote markets.

The ultimate goal of the DAO is to drive as much ETH as possible to the sweeping mechanism, scaling the treasury with desirable, yield-generating collections and becoming a major player in the inevitable multi-trillion-dollar metaverse.


## What does FLOOR do?

The FLOOR token acts as the gatekeeper of the Floor treasury. It allows the holder to decide what NFT collections are allowed into the treasury, and of these collections, which should be swept each week.

With sufficient yield generated from NFT-Fi strategies and protocol-owned products, the value of each week’s sweep will help to position FLOOR holders as kingmakers of new NFT collections.

Ultimately, FLOOR is a token that coordinates capital to solve the inherent liquidity and financial utility issues of NFT collections.


## Deployment

When deploying the network, there is a sequential deployment process in `script/deployment`. These should be run in numerical order and all latest deployment addresses will be stored in `deployment-addresses.json` when deployed.

The private wallet key that will fund the deployment and become the owner of any `Ownable` contracts is stored in the `.privatekey` file.

The following `forge script` parameters should be used (of course varying the file and class name):

```
source .env
forge script script/deployment/101_DeployAuthorityRegistry.s.sol:DeployAuthorityRegistry --broadcast --verify --chain-id=5 --rpc-url=${GOERLI_RPC_URL} --optimize --optimizer-runs=200
```

When we come to deploy finalised contracts then it could be beneficial to persist contract addresses across networks. To do this in Foundry we can use the following guide:
https://pyk.sh/tutorials/how-to-deploy-smart-contract-to-the-same-address-across-networks/


### Chain IDs
Additional chain IDs can be found here: https://chainlist.org/

- Mainnet: 1
- Goerli: 5
- Sepolia: 11155111


### Testing deployment on Anvil
Anvil is a local testnet node for deploying and testing smart contracts via Foundry Forge. It can also be used to fork other EVM compatible networks.

We can use Anvil to test deployment by first calling `anvil` and then using the localhost address being listened to as the `--rpc-url` value. We also need to remove the `--verify` call as etherscan won't have context of it.
