const { expect } = require('chai');
const { ethers, network, upgrades } = require('hardhat');

// Store our contracts
let executor, floor;

// The contract address for USDC
const USDC = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';


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
    executor = await UniswapV3PricingExecutor.deploy('0x61fFE014bA17989E743c5F6cB21bF9697530B21e', floor.address);
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

    [deployer, alice, bob, carol, ...users] = await ethers.getSigners();

    //
    quoter = new ethers.Contract(
      '0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6',
      '[{"inputs":[{"internalType":"bytes","name":"path","type":"bytes"},{"internalType":"uint256","name":"amountIn","type":"uint256"}],"name":"quoteExactInput","outputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"tokenIn","type":"address"},{"internalType":"address","name":"tokenOut","type":"address"},{"internalType":"uint24","name":"fee","type":"uint24"},{"internalType":"uint256","name":"amountIn","type":"uint256"},{"internalType":"uint160","name":"sqrtPriceLimitX96","type":"uint160"}],"name":"quoteExactInputSingle","outputs":[{"internalType":"uint256","name":"amountOut","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"bytes","name":"path","type":"bytes"},{"internalType":"uint256","name":"amountOut","type":"uint256"}],"name":"quoteExactOutput","outputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"tokenIn","type":"address"},{"internalType":"address","name":"tokenOut","type":"address"},{"internalType":"uint24","name":"fee","type":"uint24"},{"internalType":"uint256","name":"amountOut","type":"uint256"},{"internalType":"uint160","name":"sqrtPriceLimitX96","type":"uint160"}],"name":"quoteExactOutputSingle","outputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}]',
      deployer
    )

    eth_price = await quoter.callStatic.quoteExactInputSingle(WETH, USDC, 3000, '1000000000000000000', 0);

    console.log(eth_price);

    // let eth_price = await executor.callStatic.getETHPrice(USDC);
    // console.log(eth_price);

    // eth_price = await executor.getETHPrice(USDC);
    // console.log(eth_price);
    // expect(eth_price).to.equal(123);
  });

  it('Should be able to value a token in FLOOR', async () => {

  });

});
