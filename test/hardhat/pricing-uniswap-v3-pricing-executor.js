const { expect } = require('chai');
const { ethers, network, upgrades } = require('hardhat');

let zetsu, dao, dev;
let factory, proxyController;
let inventoryStaking, lpStaking, stakingZap, feeDistributor;
let paycVault, paycNft, paycVaultId, paycNftIds;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

describe('Mainnet unstaking test ERC721', function () {

  /**
   * Before we can test, we need to take a snapshot of a specific mainnet block
   * number. This is because we need to ensure that our returned values are consistent
   * over the evolution of our tests and codebase.
   */

  before('Setup', async () => {
    // Set up our block reset
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_MAINNET_API_KEY}`,
            blockNumber: 16_075_930,
          },
        },
      ],
    });

    // We can then set up our account impersonations for any involved addresses
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0xc6c2d5ee69745a1e9f2d1a06e0ef0788bd924302"],
    });

    // When the address is impersonated we can cast it to a variable
    zetsu = await ethers.provider.getSigner("0xc6c2d5ee69745a1e9f2d1a06e0ef0788bd924302");

    // Get our relevant contracts
    factory = await ethers.getContractAt(
      "NFTXVaultFactoryUpgradeable",
      "0xBE86f647b167567525cCAAfcd6f881F1Ee558216"
    );
  });

  it('Should ...', async () => {});

});
