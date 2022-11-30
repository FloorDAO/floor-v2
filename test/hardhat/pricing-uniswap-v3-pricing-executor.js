const { expect } = require('chai');
const { ethers, network, upgrades } = require('hardhat');

// Store our contracts
let executor, floor;

// The contract address for USDC
const USDC = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';


describe('Mainnet unstaking test ERC721', function () {

  /**
   * Before we can test, we need to take a snapshot of a specific mainnet block
   * number. This is because we need to ensure that our returned values are consistent
   * over the evolution of our tests and codebase.
   */

  before('Setup', async () => {
    // Set up our block reset
    await network.provider.request({
      method: 'hardhat_reset',
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.MAINNET_RPC_URL,
            blockNumber: 16_075_930,
          },
        },
      ],
    });

    // We can reference our existing FLOOR token implementation as there are existing Uniswap
    // pools for the token.
    floor = await ethers.getContractAt('FLOOR', '0xf59257e961883636290411c11ec5ae622d19455e');

    // Set up our pricing executor
    const UniswapV3PricingExecutor = await ethers.getContractFactory('UniswapV3PricingExecutor');
    executor = await UniswapV3PricingExecutor.deploy('0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6', floor.address);
    await executor.deployed();
  });


  /**
   * We need to check that we can get the stored ETH price of a token. This will make
   * a call to the Uniswap Quoter contract to take a snapshot of the current price, without
   * executing the call.
   *
   * This is done in a strange way, however. It appears that the call will revert whilst
   * still returning the data value. For this reason it has to be made via a static call.
   *
   * https://uniswapv3book.com/docs/milestone_2/quoter-contract/
   */

  it('Should be able to value a token in ETH', async () => {
    console.log(executor);
    console.log(await executor.name());
    console.log(await executor.getPriceFreshness(USDC));

    let eth_price = executor.callStatic.getETHPrice(USDC);
    expect(eth_price).to.equal(123);
  });

  it('Should be able to value a token in FLOOR', async () => {

  });

});
