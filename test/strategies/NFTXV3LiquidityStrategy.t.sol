// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from './../mocks/erc/ERC20Mock.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {INFTXRouter} from "@nftx-protocol-v3/interfaces/INFTXRouter.sol";
import {INFTXVaultV3} from '@nftx-protocol-v3/interfaces/INFTXVaultV3.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {StrategyRegistry} from '@floor/strategies/StrategyRegistry.sol';
import {NFTXV3LiquidityStrategy} from '@floor/strategies/NFTXV3LiquidityStrategy.sol';
import {CannotDepositZeroAmount} from '@floor/utils/Errors.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {INonfungiblePositionManager} from "@uni-periphery/interfaces/INonfungiblePositionManager.sol";

import {FloorTest} from '../utilities/Environments.sol';


interface IMintable {
    function mint(uint) external returns (uint[] memory);
    function setApprovalForAll(address, bool) external;
}


/**
 * Creates a liquidity position on NFTX V3.
 */
contract NFTXV3LiquidityStrategyTest is FloorTest {
    /// The Sepolia address of the NFTX Router
    address internal constant NFTX_ROUTER = 0xD36ece08F76c50EC3F01db65BBc5Ef5Aa5fbE849;
    uint24 internal constant POOL_FEE = 3000;  // 1% = 1_0000

    /// Two tokens that we can test with
    address internal constant TOKEN_A = 0xEa0bb4De9f595439059aF786614DaF2FfADa72d5; // MILADY
    address internal constant TOKEN_B = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // WETH (18 decimals)

    /// Register our pool address
    address internal constant POOL = 0x5dAaeaCE8DD7CC1A3E1Ec70dd5423Be44F3c564D;  // MILADY/ETH @ 3% (18 decimals)

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 4_834_693;

    /// Store our internal contracts
    CollectionRegistry collectionRegistry;
    StrategyFactory strategyFactory;
    StrategyRegistry strategyRegistry;
    NFTXV3LiquidityStrategy strategy;

    /// Store our strategy ID
    uint strategyId;

    /// Store our strategy implementation address
    address strategyImplementation;

    /// Store a {Treasury} wallet address
    address treasury;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() {
        // Generate a Sepolia fork
        uint sepoliaFork = vm.createFork(vm.rpcUrl('sepolia'));

        // Select our fork for the VM
        vm.selectFork(sepoliaFork);
        assertEq(vm.activeFork(), sepoliaFork);

        // Set our block ID to a specific, test-suitable number
        vm.rollFork(BLOCK_NUMBER);
        require(block.number == BLOCK_NUMBER);

        // Deploy our authority contracts
        super._deployAuthority();

        // Deploy our strategy implementation
        strategyImplementation = address(new NFTXV3LiquidityStrategy());

        // Define a treasury wallet address that we can test against
        treasury = users[1];

        // Create our {CollectionRegistry} and approve our collections
        collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        collectionRegistry.approveCollection(0xEa0bb4De9f595439059aF786614DaF2FfADa72d5); // Milady

        // Create our {StrategyRegistry} and approve our implementation
        strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        strategyRegistry.approveStrategy(strategyImplementation, true);

        // Create our {StrategyFactory}
        strategyFactory = new StrategyFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry)
        );
        strategyFactory.setTreasury(treasury);

        uint _tickDistance = _getTickDistance(POOL_FEE);

        // Deploy our strategy
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('MILADY/WETH Full Range Pool'),
            strategyImplementation,
            abi.encode(
                3, // vaultId
                NFTX_ROUTER, // router
                POOL_FEE,
                0,
                _getLowerTick(_tickDistance),
                _getUpperTick(_tickDistance)
            ),
            0xEa0bb4De9f595439059aF786614DaF2FfADa72d5
        );

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = NFTXV3LiquidityStrategy(payable(_strategy));
        strategyId = _strategyId;
    }

    /**
     * Checks that we can get the strategy name set in the constructor.
     */
    function test_CanGetName() public {
        assertEq(strategy.name(), 'MILADY/WETH Full Range Pool');
    }

    /**
     * Ensures that we have the correct tokens attached to the strategy.
     */
    function test_CanGetTokens() public {
        address[] memory tokens = strategy.validTokens();
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
    }

    /**
     * Ensures that we can correctly find the strategy ID that was deployed with the strategy.
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    function test_CanCreateNewPosition() external {
        // Before our first deposit our positionId should be 0
        assertEq(strategy.positionId(), 0);

        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make our initial deposit that will mint our token (1 vToken + 100 ETH). As this is
        // our first deposit, this will also mint a token.
        (uint amount0, uint amount1) = strategy.deposit{value: 100 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // Confirm the positionId that has been minted and that our strategy contract is the owner
        assertEq(strategy.positionId(), 35, 'Incorrect position ID');
        assertEq(
            ERC721(address(strategy.positionManager())).ownerOf(strategy.positionId()),
            address(strategy),
            'Owner of the position ID NFT is incorrect'
        );

        // Confirm our callback results
        assertEq(amount0, 1 ether, 'Invalid vToken (amount0) added');
        assertEq(amount1, 633606347970233477, 'Invalid WETH (amount1) added');
    }

    function test_CanDepositIntoExistingPosition() public {
        // Before our first deposit our positionId should be 0
        assertEq(strategy.positionId(), 0);

        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make a deposit to mint our position
        (uint amount0, uint amount1) = strategy.deposit{value: 50 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // We should now hold an expected position ID
        assertEq(strategy.positionId(), 35);

        // We can now make an additional deposit that will just increase our
        // liquidity position, whilst maintaining the same position ID.
        // Make a deposit to mint our position
        (uint amount2, uint amount3) = strategy.deposit{value: 50 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // Confirm that we have the same position ID
        assertEq(strategy.positionId(), 35);

        assertEq(amount0, 1 ether, 'Invalid vToken (amount0) added');
        assertEq(amount1, 633606347970233477, 'Invalid WETH (amount1) added');
        assertEq(amount2, 1 ether, 'Invalid vToken (amount2) added');
        assertEq(amount3, 633606347970233477, 'Invalid WETH (amount3) added');
    }

    function test_CannotDepositZeroValue() public {
        // Cannot deposit with 0 of either token
        vm.expectRevert(CannotDepositZeroAmount.selector);
        strategy.deposit{value: 0}({
            vTokenDesired: 0,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // As we were unable to successfully deposit, will still won't have any token minted
        assertEq(strategy.positionId(), 0);
    }

    function test_CanWithdraw() public {
        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make a deposit to mint our position
        (uint amount0, uint amount1) = strategy.deposit{value: 100 ether}({
            vTokenDesired: 10 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // We should now hold an expected position ID
        assertEq(strategy.positionId(), 35);

        // Confirm our callback results
        assertEq(amount0, 10000000000000000000, 'Incorrect amount0');
        assertEq(amount1, 6336063479702334768, 'Incorrect amount1');

        // Confirm that our {Treasury} currently holds no tokens
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 0);

        // Get our liquidity from our position
        (,,,,,,, uint liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 7959939371441427485, 'Incorrect liquidity');

        // Find when our timelock will expire
        uint lockedUntil = strategy.positionManager().lockedUntil(strategy.positionId());
        assertGt(lockedUntil, block.timestamp);

        // We need to warp to bypass the timelock
        vm.warp(lockedUntil + 1);

        // We can now withdraw from the strategy
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 4))
        );

        // Confirm that we now hold the token we expect. We also receive ETH, rather than WETH, so
        // we need to check our balance directly. Our ETH balance of the {Treasury} is 0 before the
        // withdraw function is called.
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 2499999999999999999);
        assertEq(payable(treasury).balance, 1584015869925583691);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 5969954528581070614, 'Incorrect liquidity');

        // We can also make a subsequent withdrawal
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 2))
        );

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 6249999999999999998);
        assertEq(payable(treasury).balance, 3960039674813959228);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 2984977264290535307, 'Incorrect liquidity');
    }

    function test_CanWithdrawPercentage() public {
        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make a deposit to mint our position
        (uint amount0, uint amount1) = strategy.deposit{value: 100 ether}({
            vTokenDesired: 10 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // We should now hold an expected position ID
        assertEq(strategy.positionId(), 35);

        // Confirm our callback results
        assertEq(amount0, 10000000000000000000, 'Incorrect amount0');
        assertEq(amount1, 6336063479702334768, 'Incorrect amount1');

        // Confirm that our {Treasury} currently holds no tokens
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 0);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 0);

        // Get our liquidity from our position
        (,,,,,,, uint liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 7959939371441427485, 'Incorrect liquidity');

        // Find when our timelock will expire
        uint lockedUntil = strategy.positionManager().lockedUntil(strategy.positionId());
        assertGt(lockedUntil, block.timestamp);

        // We need to warp to bypass the timelock
        vm.warp(lockedUntil + 1);

        // Action a 20% percentage withdrawal through the strategy factory
        (address[] memory tokens, uint[] memory amounts) = strategyFactory.withdrawPercentage(address(strategy), 20_00);

        // Confirm our response variables
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
        assertEq(amounts[0], 1999999999999999999);
        assertEq(amounts[1], 1267212695940466953);

        // Confirm that our recipient received the expected amount of tokens
        assertEq(IERC20(TOKEN_A).balanceOf(address(this)), 91999999999999999999);
        assertEq(payable(address(this)).balance, 94931149216238132185);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 6367951497153141988, 'Incorrect liquidity');

        // We can now withdraw the remaining 100%
        uint[] memory newAmounts;
        (tokens, newAmounts) = strategyFactory.withdrawPercentage(address(strategy), 100_00);

        // Confirm our response variables
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
        assertEq(newAmounts[0], 7999999999999999999);
        assertEq(newAmounts[1], 5068850783761867813);

        // Confirm that our recipient received the expected amount of tokens
        assertEq(IERC20(TOKEN_A).balanceOf(address(this)), 99999999999999999998);
        assertEq(payable(address(this)).balance, 99999999999999999998);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 0, 'Incorrect liquidity');
    }

    function test_CanGetPoolTokenBalancesWithoutActivePosition() public {
        // Get our token balances without a position ID registered
        (uint token0Amount, uint token1Amount, uint128 liquidityAmount) = strategy.tokenBalances();
        assertEq(token0Amount, 0);
        assertEq(token1Amount, 0);
        assertEq(liquidityAmount, 0);
    }

    function test_CanGetAvailableTokensWithoutPosition() public {
        (address[] memory tokens_, uint[] memory amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A);
        assertEq(tokens_[1], TOKEN_B);

        assertEq(amounts_[0], 0);
        assertEq(amounts_[1], 0);
    }

    function test_CanGetAvailableTokensWithPositionAndTokensOwed() public {
        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make our initial deposit that will mint our token (1 vToken + 100 ETH). As this is
        // our first deposit, this will also mint a token.
        strategy.deposit{value: 100 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // Confirm the positionId that has been minted and that our strategy contract is the owner
        assertEq(strategy.positionId(), 35, 'Incorrect position ID');

        // Mint some MILADY tokens against our test contract and generate fees
        _generateLiquidityFees();

        // Check our strategies available tokens call
        (address[] memory tokens_, uint[] memory amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A, 'Incorrect token0');
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(tokens_[1], TOKEN_B, 'Incorrect token1');
        assertEq(amounts_[1], 9223308835697248, 'Incorrect amount1');

        // Collect fees from the pool
        vm.startPrank(address(strategy));
        (uint amount0, uint amount1) = strategy.positionManager().collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: strategy.positionId(),
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        vm.stopPrank();

        // Compare the amounts collected to the amounts that we were read as available
        assertEq(amount0, amounts_[0]);
        assertEq(amount1, amounts_[1]);
    }

    function test_CanGetAvailableBalanceWithMultipleIntermediaryInteractions() public {
        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make our initial deposit that will mint our token (1 vToken + 100 ETH). As this is
        // our first deposit, this will also mint a token.
        strategy.deposit{value: 50 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // Confirm the positionId that has been minted and that our strategy contract is the owner
        assertEq(strategy.positionId(), 35, 'Incorrect position ID');

        // Check our lifetime rewards start as nothing
        (address[] memory lifetimeRewardsTokens, uint[] memory lifetimeRewards) = strategy.totalRewards();
        assertEq(lifetimeRewardsTokens[0], TOKEN_A);
        assertEq(lifetimeRewardsTokens[1], TOKEN_B);
        assertEq(lifetimeRewards[0], 0);
        assertEq(lifetimeRewards[1], 0);

        // Generate pool liquidity
        _generateLiquidityFees();

        // Check our strategies available tokens call
        (address[] memory tokens_, uint[] memory amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A, 'Incorrect token0');
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(tokens_[1], TOKEN_B, 'Incorrect token1');
        assertEq(amounts_[1], 9223308835697248, 'Incorrect amount1');

        // Our total rewards will reflect the available fees as well, but no other rewards
        // have yet been claimed.
        (, lifetimeRewards) = strategy.totalRewards();
        assertEq(lifetimeRewards[0], 0);
        assertEq(lifetimeRewards[1], 9223308835697248);

        // Warp forward in time and generate more liquidity
        vm.warp(block.timestamp + 4 weeks);
        _generateLiquidityFees();

        // Check our strategies available tokens call
        (tokens_, amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A, 'Incorrect token0');
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(tokens_[1], TOKEN_B, 'Incorrect token1');
        assertEq(amounts_[1], 18446617671394497, 'Incorrect amount1');

        // Collect fees from the pool
        vm.prank(strategy.owner());
        strategy.harvest(treasury);

        // Confirm that available fees are now null
        (tokens_, amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A, 'Incorrect token0');
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(tokens_[1], TOKEN_B, 'Incorrect token1');
        assertEq(amounts_[1], 0, 'Incorrect amount1');

        // Once fees have been collected, our total rewards will increase
        (, lifetimeRewards) = strategy.totalRewards();
        assertEq(lifetimeRewards[0], 0);
        assertEq(lifetimeRewards[1], 18446617671394497);

        // Confirm that our {Treasury} holds the collected fees. The collect will give the
        // correct TOKEN_B value, which is WETH as this was called directly against the
        // {PositionManager}.
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 0, 'Invalid Treasury vToken');
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), lifetimeRewards[1], 'Invalid Treasury WETH');

        // Generate some more liquidity after we have collected
        _generateLiquidityFees();

        // Confirm the available fees
        (tokens_, amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A, 'Incorrect token0');
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(tokens_[1], TOKEN_B, 'Incorrect token1');
        assertEq(amounts_[1], 9223308835697248, 'Incorrect amount1');

        // Add some more liquidity to our position
        strategy.deposit{value: 50 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });

        // Confirm the available fees
        (tokens_, amounts_) = strategy.available();
        assertEq(tokens_[0], TOKEN_A, 'Incorrect token0');
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(tokens_[1], TOKEN_B, 'Incorrect token1');
        assertEq(amounts_[1], 9223308835697248, 'Incorrect amount1');

        // Move time foward to unlock our position
        vm.warp(block.timestamp + 7 days);

        // If we remove liquidity, we should also action a harvest which will also update
        // our rewards.
        (,, uint128 liquidity) = strategy.tokenBalances();
        assertEq(liquidity, 1591987874288285496, 'Incorrect liquidity');
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(
                strategy.withdraw.selector,
                0,
                0,
                block.timestamp,
                liquidity / 4
            )
        );

        // After we have withdrawn from our liquidity position, this will internally
        // trigger a collection event. This should be reflected in the totalRewards call
        // and also remove the available fees.
        (, amounts_) = strategy.available();
        assertEq(amounts_[0], 0, 'Incorrect amount0');
        assertEq(amounts_[1], 0, 'Incorrect amount1');

        (, lifetimeRewards) = strategy.totalRewards();
        assertEq(lifetimeRewards[0], 0);
        assertEq(lifetimeRewards[1], 27669926507091745);

        // Confirm that our {Treasury} holds the collected fees. This will also include the
        // additional amounts that have been withdrawn, but these are not reflected in the
        // lifetime rewards.
        //
        // The ETH and WETH is split on the {Treasury} from different methods of token
        // receipt. WETH is received from collect and ETH is received when withdrawing from
        // an existing liquidity position.
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 499999999999999999, 'Invalid Treasury vToken');
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 27669926507091745, 'Invalid Treasury WETH');
        assertEq(payable(treasury).balance, 316803173985116738, 'Invalid Treasury ETH');

        // After our withdraw, we should have no fees to collect
        vm.startPrank(address(strategy));
        (uint amount0, uint amount1) = strategy.positionManager().collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: strategy.positionId(),
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        vm.stopPrank();

        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_CanHarvestWithoutActivePosition() public {
        vm.prank(strategy.owner());
        strategy.harvest(address(this));
    }

    function test_CanWithdrawWithoutActivePosition() public {
        vm.prank(strategy.owner());
        (address[] memory tokens_, uint[] memory amounts_) = strategy.withdraw(address(this), 0, 0, block.timestamp, 0);

        assertEq(tokens_.length, 0);
        assertEq(amounts_.length, 0);
    }

    function _getLowerTick(uint _tickDistance) internal pure returns (int24 i) {
        for (i = -887272; ; ++i) {
            if (i % int24(int(_tickDistance)) == 0) {
                return i;
            }
        }
    }

    function _getUpperTick(uint _tickDistance) internal pure returns (int24 i) {
        for (i = 887272; ; --i) {
            if (i % int24(int(_tickDistance)) == 0) {
                return i;
            }
        }
    }

    function _getTickDistance(uint24 fee) internal returns (uint tickDistance_) {
        tickDistance_ = uint(uint24(IUniswapV3Factory(INFTXRouter(NFTX_ROUTER).router().factory()).feeAmountTickSpacing(fee)));
    }

    function _generateLiquidityFees() internal {
        // Mint some MILADY tokens against our test contract
        uint[] memory miladyTokens = IMintable(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).mint(3);
        uint[] memory amounts = new uint[](miladyTokens.length);
        for (uint i; i < miladyTokens.length; ++i) {
            amounts[i] = 1;
        }

        // Approve all tokens to be minted
        IMintable(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).setApprovalForAll(0xEa0bb4De9f595439059aF786614DaF2FfADa72d5, true);

        // Mint into the pool
        INFTXVaultV3(0xEa0bb4De9f595439059aF786614DaF2FfADa72d5).mint{value: 10 ether}(
            miladyTokens,
            amounts,
            address(this),
            address(this)
        );
    }

    receive() external payable {
        // ..
    }

}
