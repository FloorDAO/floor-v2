// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20Mock} from './../mocks/erc/ERC20Mock.sol';

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

import {INFTXRouter} from "@nftx-protocol-v3/interfaces/INFTXRouter.sol";
import {INFTXVaultV3} from '@nftx-protocol-v3/interfaces/INFTXVaultV3.sol';
import {IUniswapV3Factory} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
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

    function test_CanGetPoolInformation() public {
        // We have no positionId currently minted
        assertEq(strategy.positionId(), 0);

        // We have our mapped NFTX data
        assertEq(strategy.vaultId(), 3);
        assertEq(address(strategy.vault()), 0xEa0bb4De9f595439059aF786614DaF2FfADa72d5);

        // We have our position / vault data
        assertEq(strategy.fee(), POOL_FEE);
        assertEq(strategy.sqrtPriceX96(), 0);
        assertEq(strategy.tickLower(), -887220);
        assertEq(strategy.tickUpper(), 887220);

        // Our vault Token address is the same as the vault
        assertEq(address(strategy.vToken()), address(strategy.vault()));

        // The WETH token is taken from the NFTX contracts and is correct for network
        assertEq(address(strategy.weth()), 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14);

        // Our pool address is deterministic, but in this instance it already exists
        assertEq(address(strategy.pool()), 0x5dAaeaCE8DD7CC1A3E1Ec70dd5423Be44F3c564D);

        // Get our NFTX contract references
        assertEq(address(strategy.router()), NFTX_ROUTER);
        assertEq(address(strategy.positionManager()), 0x55BDc76262B1e6e791D0636A0bC61cee23CDFa87);
    }

    /**
     * Ensures that we can correctly find the strategy ID that was deployed with the strategy.
     */
    function test_CanGetStrategyId() public {
        assertEq(strategy.strategyId(), 0);
    }

    /**
     * A previous issue that we had with the contract that was not tested, was that if a strategy was
     * deployed
     */
    function test_CanInitializeWithPoolThatDoesNotExist() public {
        uint newVaultId = 5;
        address newVaultToken = 0xdCA1A3D2b0FF6b4ca62C697811f7680d7990CCF7;
        uint24 newPoolFee = 3_000;

        // Deploy a new strategy implementation with a pool that does not exist. The collection referenced
        // is not the same as the NFTX pool, but this is only checked in our {CollectionRegistry}.
        uint _tickDistance = _getTickDistance(newPoolFee);
        (, address _strategy) = strategyFactory.deployStrategy(
            bytes32('CAT/WETH Full Range Pool'),
            strategyImplementation,
            abi.encode(
                newVaultId, // vaultId
                NFTX_ROUTER, // router
                newPoolFee,
                0,
                _getLowerTick(_tickDistance),
                _getUpperTick(_tickDistance)
            ),
            0xEa0bb4De9f595439059aF786614DaF2FfADa72d5
        );

        // Map the newly created strategy to our contract
        strategy = NFTXV3LiquidityStrategy(payable(_strategy));

        // Set our expected deterministic address
        address expectedAddress = 0x177Ce401302E994c90C426525e526bfFe2698627;

        // Confirm that we have a deterministic pool address
        assertEq(strategy.pool(), expectedAddress);

        // Confirm that the pool does not actually exist
        (address _pool, bool _exists) = strategy.router().getPoolExists(newVaultId, newPoolFee);
        assertEq(_pool, address(0));
        assertEq(_exists, false);

        // After placing a deposit tx with the below data, we can see that the `expectedAddress`
        // is the Pool that is created. The below code can be uncommented to confirm this. This
        // currently reverts due to `R()`.

        /*
        deal(address(this), 10 ether);
        deal(newVaultToken, address(this), 1 ether);
        IERC20(newVaultToken).approve(address(strategy), type(uint).max);
        strategy.deposit{value: 10 ether}({
            vTokenDesired: 1 ether,
            nftIds: new uint[](0),
            nftAmounts: new uint[](0),
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp
        });
        */
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

    function test_CanCreateNewPositionWithNftDeposit() public {
        // Ensure that we have a position amount of NFTs and limit to realistic size
        // for test speed
        uint _nftIds = 10;

        // Before our first deposit our positionId should be 0
        assertEq(strategy.positionId(), 0);

        // Mint some NFTs
        uint[] memory nftIds = IMintable(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).mint(_nftIds);
        uint[] memory nftAmounts = new uint[](_nftIds);
        for (uint i; i < _nftIds; ++i) {
            nftAmounts[i] = 1;
        }

        // Approve our ERC721's to be used
        ERC721(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).setApprovalForAll(address(strategy), true);

        // Deal us some ETH to deposit
        deal(address(this), 100 ether);

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Make our initial deposit that will mint our token
        (uint amount0, uint amount1) = strategy.deposit{value: 100 ether}({
            vTokenDesired: 0,
            nftIds: nftIds,
            nftAmounts: nftAmounts,
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });

        // Confirm the positionId that has been minted and that our strategy contract is the owner
        assertEq(strategy.positionId(), 35, 'Incorrect position ID');
        assertEq(
            ERC721(address(strategy.positionManager())).ownerOf(strategy.positionId()),
            address(strategy),
            'Owner of the position ID NFT is incorrect'
        );

        // Confirm our callback results
        assertEq(amount0, _nftIds * 1 ether, 'Invalid vToken (amount0) added');
        assertEq(amount1, 6336063479702334768, 'Invalid WETH (amount1) added');
    }

    function test_CanCreateNewPositionWithHybridTokenAndNft() external {
        // Before our first deposit our positionId should be 0
        assertEq(strategy.positionId(), 0);

        // Deal us some assets to deposit
        deal(TOKEN_A, address(this), 100 ether);
        deal(address(this), 100 ether);

        // Mint some NFTs
        uint _nftIds = 6;
        uint[] memory nftIds = IMintable(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).mint(_nftIds);
        uint[] memory nftAmounts = new uint[](_nftIds);
        for (uint i; i < _nftIds; ++i) {
            nftAmounts[i] = 1;
        }

        // Set our max approvals
        IERC20(TOKEN_A).approve(address(strategy), type(uint).max);

        // Approve our ERC721's to be used
        ERC721(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).setApprovalForAll(address(strategy), true);

        // Make our initial deposit that will mint our token (1 vToken + 100 ETH). As this is
        // our first deposit, this will also mint a token.
        (uint amount0, uint amount1) = strategy.deposit{value: 100 ether}({
            vTokenDesired: 4 ether,
            nftIds: nftIds,
            nftAmounts: nftAmounts,
            vTokenMin: 3 ether,
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
        assertEq(amount0, 10 ether, 'Invalid vToken (amount0) added');
        assertEq(amount1, 6336063479702334768, 'Invalid WETH (amount1) added');

        // Mint some new NFTs
        nftIds = IMintable(0xeA9aF8dBDdE2A8d3515C3B4E446eCd41afEdB1C6).mint(_nftIds);

        // Make a subsequent deposit
        strategy.deposit{value: 50 ether}({
            vTokenDesired: 3 ether,
            nftIds: nftIds,
            nftAmounts: nftAmounts,
            vTokenMin: 3 ether,
            wethMin: 0,
            deadline: block.timestamp
        });
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
            strategyId,
            abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 4))
        );

        // Confirm that we now hold the token we expect. We want to ensure that all of our
        // received ETH is wrapped into WETH before being sent to us. For this reason we
        // expect that we will have ETH balance.
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 2499999999999999999);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 1584015869925583691);
        assertEq(payable(treasury).balance, 0);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 5969954528581070614, 'Incorrect liquidity');

        // We can also make a subsequent withdrawal
        strategyFactory.withdraw(
            strategyId, abi.encodeWithSelector(strategy.withdraw.selector, 0, 0, block.timestamp, uint128(liquidity / 2))
        );

        // Confirm that we now hold the token we expect
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 6249999999999999998);
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 3960039674813959228);
        assertEq(payable(treasury).balance, 0);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 2984977264290535307, 'Incorrect liquidity');
    }

    function test_CannotWithdrawPercentage() public {
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

        // Try to action a 20% percentage withdrawal through the strategy factory
        (address[] memory tokens, uint[] memory amounts) = strategyFactory.withdrawPercentage(address(strategy), 20_00);

        // Confirm our response variables
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
        assertEq(amounts[0], 0);
        assertEq(amounts[1], 0);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 7959939371441427485, 'Incorrect liquidity');

        // Try to withdraw the remaining 100%
        uint[] memory newAmounts;
        (tokens, newAmounts) = strategyFactory.withdrawPercentage(address(strategy), 100_00);

        // Confirm our response variables
        assertEq(tokens[0], TOKEN_A);
        assertEq(tokens[1], TOKEN_B);
        assertEq(newAmounts[0], 0);
        assertEq(newAmounts[1], 0);

        // Get our liquidity from our position
        (,,,,,,, liquidity,,,,) = strategy.positionManager().positions(strategy.positionId());
        assertEq(liquidity, 7959939371441427485, 'Incorrect liquidity');
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

        // Collect fees from the pool. This should not be done via this route in proper
        // execution, as it would be done through the `harvest` function.
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
        // The ETH should be "deposited" into WETH in the {Treasury} from different methods of
        // token receipt. WETH is received from collect and ETH is received when withdrawing from
        // an existing liquidity position.
        assertEq(IERC20(TOKEN_A).balanceOf(treasury), 499999999999999999, 'Invalid Treasury vToken');
        assertEq(IERC20(TOKEN_B).balanceOf(treasury), 344473100492208483, 'Invalid Treasury WETH');
        assertEq(payable(treasury).balance, 0, 'Invalid Treasury ETH');

        // After our withdraw, we should have no fees to collect
        vm.startPrank(address(strategy));
        (uint amount0, uint amount1) = strategy.positionManager().collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: strategy.positionId(),
                recipient: treasury,
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


contract NFTXV3LiquidityStrategyDeploymentTest is FloorTest {
    /// Register our pool address
    address internal constant POOL = 0x7a804F54d1f002C429DC1ca8B989afF779dFBf1B;  // MILADY/ETH @ 3% (18 decimals)
    uint internal constant POOL_ID = 8;

    /// Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 19_386_305;

    /// Store our internal contracts
    StrategyFactory strategyFactory;
    NFTXV3LiquidityStrategy strategy;

    /// Store our strategy ID
    uint strategyId;

    /**
     * Sets up our mainnet fork and register our action contract.
     */
    constructor() forkBlock(BLOCK_NUMBER) {}

    function setUp() public {
        // Create our {StrategyFactory}
        strategyFactory = StrategyFactory(0xdf2e023Ea56d752D0B5bE79f65557987976676CC);

        // Deploy our strategy
        vm.startPrank(0x81B14b278081e2052Dcd3C430b4d13efA1BC392D);
        (uint _strategyId, address _strategy) = strategyFactory.deployStrategy(
            bytes32('NFTX V3 - YAYO/WETH'),
            0x663c650f1b765B1a4209c33bADEafFca58C433BB,
            abi.encode(
                POOL_ID,
                0x70A741A12262d4b5Ff45C0179c783a380EebE42a,
                3000,
                38400000000000000000000000000,
                -887220,
                887220
            ),
            0x09f66a094a0070EBDdeFA192a33fa5d75b59D46b
        );
        vm.stopPrank();

        // Cast our strategy to the NFTX Inventory Staking Strategy contract
        strategy = NFTXV3LiquidityStrategy(payable(_strategy));
        strategyId = _strategyId;
    }

    function test_CanDoStuff() public {
        // Before our first deposit our positionId should be 0
        assertEq(strategy.positionId(), 0);

        address payable holder = payable(0x0781B192F48706310082268A4C037078F2e8B9B0);

        vm.startPrank(holder);

        // Deal us some assets to deposit
        deal(holder, 100 ether);

        // Approve our ERC721's to be used
        ERC721(0x09f66a094a0070EBDdeFA192a33fa5d75b59D46b).setApprovalForAll(address(strategy), true);

        uint[] memory nftIds = new uint[](5);
        nftIds[0] = 1066;
        nftIds[1] = 1077;
        nftIds[2] = 1150;
        nftIds[3] = 1231;
        nftIds[4] = 1276;

        uint[] memory nftAmounts = new uint[](5);
        nftAmounts[0] = 1;
        nftAmounts[1] = 1;
        nftAmounts[2] = 1;
        nftAmounts[3] = 1;
        nftAmounts[4] = 1;

        // Make our initial deposit that will mint our token
        (uint amount0, uint amount1) = strategy.deposit{value: 1.5 ether}({
            vTokenDesired: 0,
            nftIds: nftIds,
            nftAmounts: nftAmounts,
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });

        // Confirm the positionId that has been minted and that our strategy contract is the owner
        assertEq(
            ERC721(address(strategy.positionManager())).ownerOf(strategy.positionId()),
            address(strategy),
            'Owner of the position ID NFT is incorrect'
        );

        // Confirm our callback results
        assertEq(amount0, 5 ether, 'Invalid vToken (amount0) added');
        assertEq(amount1, 1.174554804239734415 ether, 'Invalid WETH (amount1) added');

        nftIds[0] = 1279;
        nftIds[1] = 1282;
        nftIds[2] = 1283;
        nftIds[3] = 1343;
        nftIds[4] = 1369;

        // Make a subsequent deposit
        strategy.deposit{value: 2 ether}({
            vTokenDesired: 0,
            nftIds: nftIds,
            nftAmounts: nftAmounts,
            vTokenMin: 0,
            wethMin: 0,
            deadline: block.timestamp + 3600
        });
    }
}
