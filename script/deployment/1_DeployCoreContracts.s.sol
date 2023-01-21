// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/Script.sol';

import '../../src/contracts/actions/nftx/SellNFTForETH.sol';
import '../../src/contracts/actions/uniswap/SellTokensForETH.sol';
import '../../src/contracts/authorities/AuthorityRegistry.sol';
import '../../src/contracts/collections/CollectionRegistry.sol';
import '../../src/contracts/migrations/MigrateFloorToken.sol';
import '../../src/contracts/options/Option.sol';
import '../../src/contracts/options/OptionDistributionWeightingCalculator.sol';
import '../../src/contracts/options/OptionExchange.sol';
import '../../src/contracts/pricing/UniswapV3PricingExecutor.sol';
import '../../src/contracts/strategies/NFTXInventoryStakingStrategy.sol';
import '../../src/contracts/strategies/NFTXLiquidityStakingStrategy.sol';
import '../../src/contracts/strategies/StrategyRegistry.sol';
import '../../src/contracts/tokens/Floor.sol';
import '../../src/contracts/vaults/Vault.sol';
import '../../src/contracts/vaults/VaultFactory.sol';
import '../../src/contracts/RewardsLedger.sol';

/**
 * Deploys our contracts and validates them on Etherscan.
 *
 * This should be run in the following command:
 *
 * ```
 * forge script script/deployment/1_DeployCoreContracts.s.sol:DeployCoreContracts \
 *      --rpc-url [RPC URL] \
 *      --broadcast \
 *      --verify \
 *      -vvvv \
 *      --private-key [PRIVATE KEY]
 * ```
 */
contract DeployCoreContracts is Script {
    function run() external {
        /*
        // Using the passed in the script call, has all subsequent calls (at this call
        // depth only) create transactions that can later be signed and sent onchain.
        vm.startBroadcast();

        AuthorityRegistry authorityRegistry = new AuthorityRegistry();

        CollectionRegistry collectionRegistry = new CollectionRegistry(address(authorityRegistry));
        StrategyRegistry strategyRegistry = new StrategyRegistry(address(authorityRegistry));
        Vault vault = new Vault(address(authorityRegistry));
        FLOOR floor = new FLOOR(address(authorityRegistry));
        // veFLOOR veFloor = new VeFLOOR(address(authorityRegistry));

        NFTXInventoryStakingStrategy inventoryStakingStrategy =
            new NFTXInventoryStakingStrategy('NFTX Inventory Staking', address(authorityRegistry));

        // Treasury treasury = new Treasury();
        VaultFactory vaultFactory = new VaultFactory(
            address(authorityRegistry),
            address(collectionRegistry),
            address(strategyRegistry),
            address(vault)
        );

        UniswapV3PricingExecutor pricingExecutor =
            new UniswapV3PricingExecutor(0x1F98431c8aD98523631AE4a59f267346ea31F984, address(floor));

        OptionExchange optionExchange = new OptionExchange(
            address(0),  //  address(treasury),
            0x514910771AF9Ca656af840dff83E8264EcF986CA,  // Chainlink Token Address
            0x5A861794B927983406fCE1D062e00b9368d97Df6   // Chainlink VRF2 wrapper: https://docs.chain.link/vrf/v2/direct-funding/supported-networks
        );

        OptionDistributionWeightingCalculator optionDistributionWeightingCalculator =
            new OptionDistributionWeightingCalculator(abi.encode(_distributionCalculatorWeights()));
        optionExchange.setOptionDistributionWeightingCalculator(address(optionDistributionWeightingCalculator));

        Option option = new Option();

        // NFTXSellNFTForETH nftxSellNFTForETH = new NFTXSellNFTForETH(, treasury);
        // UniswapSellTokensForETH uniswapSellTokensForETH = new UniswapSellTokensForETH(, treasury);

        MigrateFloorToken migrateFloorToken = new MigrateFloorToken(address(floor));

        // Stop collecting onchain transactions
        vm.stopBroadcast();
        */
    }

    function _distributionCalculatorWeights() internal returns (uint[] memory) {
        // Set our weighting ladder
        uint[] memory _weights = new uint[](21);
        _weights[0] = 1453;
        _weights[1] = 2758;
        _weights[2] = 2653;
        _weights[3] = 2424;
        _weights[4] = 2293;
        _weights[5] = 1919;
        _weights[6] = 1725;
        _weights[7] = 1394;
        _weights[8] = 1179;
        _weights[9] = 887;
        _weights[10] = 700;
        _weights[11] = 524;
        _weights[12] = 370;
        _weights[13] = 270;
        _weights[14] = 191;
        _weights[15] = 122;
        _weights[16] = 100;
        _weights[17] = 51;
        _weights[18] = 29;
        _weights[19] = 18;
        _weights[20] = 12;

        return _weights;
    }
}
