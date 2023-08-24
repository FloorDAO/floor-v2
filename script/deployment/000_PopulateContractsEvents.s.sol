// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';

import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from '../../test/mocks/erc/ERC1155Mock.sol';

import {RegisterSweepTrigger} from '@floor/triggers/RegisterSweep.sol';
import {LiquidateNegativeCollectionTrigger} from '@floor/triggers/LiquidateNegativeCollection.sol';
import {StoreEpochCollectionVotesTrigger} from '@floor/triggers/StoreEpochCollectionVotes.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {AuthorityRegistry} from '@floor/authorities/AuthorityRegistry.sol';
import {VeFloorStaking} from '@floor/staking/VeFloorStaking.sol';
import {CollectionRegistry} from '@floor/collections/CollectionRegistry.sol';
import {StrategyFactory} from '@floor/strategies/StrategyFactory.sol';
import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';
import {SweepWars} from '@floor/voting/SweepWars.sol';
import {RageQuit} from '@floor/RageQuit.sol';
import {EpochManager} from '@floor/EpochManager.sol';
import {SendEth} from '@floor/actions/utils/SendEth.sol';
import {ManualSweeper} from '@floor/sweepers/Manual.sol';
import {Treasury} from '@floor/Treasury.sol';

import {IWETH} from '@floor-interfaces/tokens/WETH.sol';
import {ITreasury, TreasuryEnums} from '@floor-interfaces/Treasury.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 * Interacts with all of our event driven contracts.
 *
 * Collection Registry:
 * 0xDc110028492D1baA15814fCE939318B6edA13098
 * 0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018
 * 0x572567C9aC029bd617CdBCF43b8dcC004A3D1339
 */
contract PopulateContractEvents is DeploymentScript {

    function run() external deployer {

        {
            // FIX: Incorrect variable passed to `RegisterSweepTrigger` deployment
            EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

            // Delete the existing trigger
            epochManager.setEpochEndTrigger(0xF7c08a79658Ad55A50F3a54CCd2645cAeDcC3A61, false);

            // Redeploy our trigger
            RegisterSweepTrigger registerSweep = new RegisterSweepTrigger(
                requireDeployment('NewCollectionWars'),
                requireDeployment('UniswapV3PricingExecutor'),
                requireDeployment('StrategyFactory'),
                requireDeployment('Treasury'),
                requireDeployment('SweepWars')
            );

            // Register our new epoch trigger
            epochManager.setEpochEndTrigger(address(registerSweep), true);
            storeDeployment('RegisterSweepTrigger', address(registerSweep));

            registerSweep.setEpochManager(address(epochManager));

            // FIX: We need to give the register sweep contract Treasury Manager permissions
            AuthorityControl authorityControl = AuthorityControl(requireDeployment('AuthorityControl'));
            AuthorityRegistry authorityRegistry = AuthorityRegistry(requireDeployment('AuthorityRegistry'));
            authorityRegistry.grantRole(authorityControl.TREASURY_MANAGER(), address(registerSweep));
        }

        {
            // FIX: Set epoch manager for {StoreEpochCollectionVotesTrigger}
            StoreEpochCollectionVotesTrigger storeEpochVotes = StoreEpochCollectionVotesTrigger(requireDeployment('StoreEpochCollectionVotesTrigger'));
            storeEpochVotes.setEpochManager(requireDeployment('EpochManager'));
        }

        {
            // FIX: Existing liquidation trigger has division error if no votes present
            EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

            // Delete the existing trigger
            epochManager.setEpochEndTrigger(0xDFDfFDD8F2791067E4ad6a6383B4eCADcAaA4e62, false);

            address[] memory strategies = StrategyFactory(requireDeployment('StrategyFactory')).strategies();

            // Register our epoch end trigger that stores our liquidation
            LiquidateNegativeCollectionTrigger liquidateNegativeCollectionTrigger = new LiquidateNegativeCollectionTrigger(
                requireDeployment('SweepWars'),
                requireDeployment('StrategyFactory'),
                strategies[0],
                0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD // Uniswap Universal Router
            );

            // Register the epoch manager against our trigger
            liquidateNegativeCollectionTrigger.setEpochManager(address(epochManager));

            // Add our epoch end trigger
            epochManager.setEpochEndTrigger(address(liquidateNegativeCollectionTrigger), true);
            storeDeployment('LiquidateNegativeCollectionTrigger', address(liquidateNegativeCollectionTrigger));
        }

        {
            // FIX: This was not previously included in the deployment scripts so needs
            // including here.
            VeFloorStaking staking = VeFloorStaking(requireDeployment('VeFloorStaking'));
            staking.setVotingContracts(requireDeployment('NewCollectionWars'), requireDeployment('SweepWars'));

            // FIX: Epoch triggers did not have the epoch manager assigned previously
            RegisterSweepTrigger(requireDeployment('RegisterSweepTrigger')).setEpochManager(requireDeployment('EpochManager'));
            StoreEpochCollectionVotesTrigger(requireDeployment('StoreEpochCollectionVotesTrigger')).setEpochManager(requireDeployment('EpochManager'));
        }

        {
            // FIX: RegisterSweepTrigger needs STRATEGY_MANAGER
            AuthorityControl authorityControl = AuthorityControl(requireDeployment('AuthorityControl'));
            AuthorityRegistry authorityRegistry = AuthorityRegistry(requireDeployment('AuthorityRegistry'));

            // emit RoleGranted(role, account, _msgSender());
            authorityRegistry.grantRole(authorityControl.STRATEGY_MANAGER(), requireDeployment('RegisterSweepTrigger'));
        }


        address WALLET = 0xa2aE3FCC8A79c0E91A8B0a152dc1b1Ef311e1348;

        // Set up a mock erc20
        ERC20Mock erc20Mock = new ERC20Mock();
        erc20Mock.setDecimals(18);
        ERC721Mock erc721Mock = ERC721Mock(0xDc110028492D1baA15814fCE939318B6edA13098);
        ERC1155Mock erc1155Mock = new ERC1155Mock();

        // Set some test tokens to our user
        uint erc721TokenId = 0;
        uint erc1155TokenId = 0;

        // Mint some tokens
        {
            erc20Mock.mint(WALLET, 100 ether);
            erc721Mock.mint(WALLET, erc721TokenId);
            erc1155Mock.mint(WALLET, erc1155TokenId, 5, '');
        }

        Treasury treasury = Treasury(requireDeployment('Treasury'));

        // Load our manual sweeper and approve for sweeping
        ManualSweeper manualSweeper = new ManualSweeper();
        treasury.approveSweeper(address(manualSweeper), true);

        // Secure test address
        address testAddress = 0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96; // twade.eth


        /**
         * src/contracts/Treasury.sol
         */

        console.log('TREASURY');

        {
            // emit FloorMinted(amount);
            treasury.mint(10 ether);

            // emit Deposit(msg.value);
            (bool sent,) = address(treasury).call{value: 1 ether}('');
            require(sent);

            // emit WithdrawERC20(token, amount, recipient);
            // When we mint FLOOR tokens it stays in the {Treasury}, so we need to withdraw
            // this first, and then deposit it back in after.
            treasury.withdrawERC20(WALLET, address(treasury.floor()), 10 ether);

            // Approve FLOOR token and NFTs to be used by Treasury
            treasury.floor().approve(address(treasury), type(uint).max);
            erc721Mock.setApprovalForAll(address(treasury), true);
            erc1155Mock.setApprovalForAll(address(treasury), true);

            // emit DepositERC20(token, amount);
            treasury.depositERC20(address(treasury.floor()), 1 ether);

            // emit DepositERC721(token, tokenId);
            treasury.depositERC721(address(erc721Mock), erc721TokenId);

            // emit DepositERC1155(token, tokenId, amount);
            treasury.depositERC1155(address(erc1155Mock), erc1155TokenId, 2);

            // emit Withdraw(amount, recipient);
            // We don't want to withdraw the full amount here as we will want to `SendEth`
            // later on.
            treasury.withdraw(WALLET, 0.2 ether);

            // emit WithdrawERC721(token, tokenId, recipient);
            treasury.withdrawERC721(WALLET, address(erc721Mock), erc721TokenId);

            // emit WithdrawERC1155(token, tokenId, amount, recipient);
            treasury.withdrawERC1155(WALLET, address(erc1155Mock), erc1155TokenId, 2);

            // emit SweepRegistered(epoch, sweepType, collections, amounts);
            address[] memory _collections = new address[](2);
            _collections[0] = address(1);
            _collections[1] = address(2);
            uint[] memory _amounts = new uint[](2);
            _amounts[0] = 1 ether;
            _amounts[1] = 2 ether;

            treasury.registerSweep(0, _collections, _amounts, TreasuryEnums.SweepType.SWEEP);
        }

        {
            // Deploy an action we can run
            SendEth action = new SendEth();

            // emit ActionProcessed(action, data);
            // emit SweepAction(linkedSweepEpoch);
            ITreasury.ActionApproval[] memory approvals = new ITreasury.ActionApproval[](1);
            approvals[0] = ITreasury.ActionApproval(
                TreasuryEnums.ApprovalType.NATIVE, // Token type
                address(0), // address assetContract
                0, // uint tokenId
                0.01 ether // uint amount
            );

            treasury.processAction(payable(address(action)), approvals, abi.encode(WALLET, 0.01 ether), 0);
        }


        /**
         * src/contracts/RageQuit.sol
         */

        {
            console.log('RAGE QUIT');

            RageQuit rageQuit = new RageQuit(address(treasury.floor()));

            // emit FundsAdded(token, amount);
            erc20Mock.approve(address(rageQuit), type(uint).max);
            rageQuit.fund(address(erc20Mock), 1 ether);

            // We need to unpause the contract to allow it to run
            rageQuit.unpause();

            // emit Paperboy(msg.sender, amount);
            treasury.floor().approve(address(rageQuit), type(uint).max);
            rageQuit.ragequit(1 ether);
        }


        /**
         * src/contracts/authorities/AuthorityRegistry.sol
         */

        {
            console.log('AUTHORITY CONTROL / REGISTRY');

            AuthorityControl authorityControl = AuthorityControl(requireDeployment('AuthorityControl'));
            AuthorityRegistry authorityRegistry = AuthorityRegistry(requireDeployment('AuthorityRegistry'));

            // emit RoleGranted(role, account, _msgSender());
            authorityRegistry.grantRole(authorityControl.COLLECTION_MANAGER(), testAddress);

            // emit RoleRevoked(role, account, _msgSender());
            authorityRegistry.revokeRole(authorityControl.COLLECTION_MANAGER(), testAddress);
        }


        /**
         * src/contracts/staking/VeFloorStaking.sol
         */

        {
            console.log('VE FLOOR STAKING');

            VeFloorStaking staking = VeFloorStaking(requireDeployment('VeFloorStaking'));

            // emit FeeReceiverSet(feeReceiver_);
            staking.setFeeReceiver(staking.feeReceiver());

            // emit MaxLossRatioSet(maxLossRatio_);
            staking.setMaxLossRatio(staking.maxLossRatio());

            // emit MinLockPeriodRatioSet(minLockPeriodRatio_);
            staking.setMinLockPeriodRatio(0);

            // emit EmergencyExitSet(emergencyExit_);
            staking.setEmergencyExit(false);

            // emit Deposit(account, amount);
            // Requires floor held in the account for this call
            treasury.floor().approve(address(staking), type(uint).max);
            staking.deposit(1 ether, 3);

            // emit Withdraw(msg.sender, balance);
            // TODO: Cannot run due to timelock: staking.earlyWithdraw(0, 1 ether);
        }


        /**
         * src/contracts/voting/NewCollectionWars.sol
         */

         console.log('NEW COLLECTION WARS');

        NewCollectionWars newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        {
            address[] memory _collections = new address[](3);
            _collections[0] = 0xDc110028492D1baA15814fCE939318B6edA13098;
            _collections[1] = 0xA08Bc5C704f17d404E6a3B93c25b1C494ea1c018;
            _collections[2] = 0x572567C9aC029bd617CdBCF43b8dcC004A3D1339;
            bool[] memory _isErc1155 = new bool[](3);
            uint[] memory _floorPrices = new uint[](3);
            _floorPrices[0] = 1 ether;
            _floorPrices[1] = 2 ether;
            _floorPrices[2] = 3 ether;
            newCollectionWars.createFloorWar(1, _collections, _isErc1155, _floorPrices);
        }


        /**
         * src/contracts/voting/SweepWars.sol
         */

        {
            console.log('SWEEP WARS');

            SweepWars sweepWars = SweepWars(requireDeployment('SweepWars'));

            // emit VoteCast(msg.sender, _collection, _amount);
            // Must have staked balance
            sweepWars.vote(address(erc721Mock), 1 ether);

            // emit VotesRevoked(_account, _collections[i], userForVotes[collectionHash], userAgainstVotes[collectionHash]);
            address[] memory _collections = new address[](1);
            _collections[0] = address(erc721Mock);
            sweepWars.revokeVotes(_collections);

            // Cast vote again so that we have content for epoch sweep
            sweepWars.vote(address(erc721Mock), 1 ether);
        }


        /**
         * src/contracts/strategies/StrategyFactory.sol
         */

        {
            console.log('STRATEGY');

            StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));

            // emit StrategyCreated(strategyId_, strategyAddr_, _collection);
            strategyFactory.deployStrategy(
                'Mock Strategy',
                requireDeployment('RevenueStakingStrategy'),
                _strategyData(),
                address(erc721Mock)
            );

            // emit StrategySnapshot(_epoch, _strategyId, tokens, amounts);
            // This should be tested when endEpoch is called.
        }


        /**
         * src/contracts/EpochManager.sol
         */

        {
            console.log('EPOCH MANAGER');

            EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

            // emit CollectionAdditionWarScheduled(epoch, index);
            // Should be fired by new collection war in the `createFloorWar` function

            // emit EpochEnded(currentEpoch, lastEpoch);
            epochManager.endEpoch();
        }


        /**
         * src/contracts/voting/NewCollectionWars.sol
         */

        {
            console.log('NEW COLLECTION WAR VOTING');

            // emit VoteCast(msg.sender, collection, userVotes[warUser], collectionVotes[warCollection]);
            newCollectionWars.vote(address(erc721Mock));

            // emit VoteRevoked(msg.sender, collection, collectionVotes[warCollection]);
            newCollectionWars.revokeVotes(WALLET);

            // emit NftVoteCast(sender, war, collection, collectionVotes[warCollection], collectionNftVotes[warCollection]);
            newCollectionWars.setOptionsContract(WALLET);
            newCollectionWars.optionVote(WALLET, 1, address(erc721Mock), 1 ether);
            newCollectionWars.setOptionsContract(address(0));
        }


        /**
         * src/contracts/Treasury.sol
         */

        {
            console.log('SWEEP EPOCH');

            // Set a minimum sweep amount as no rewards will have been generated
            console.log(address(treasury.weth()));
            console.log(treasury.weth().balanceOf(address(treasury)));

            treasury.weth().deposit{value: 0.5 ether}();
            treasury.weth().transfer(address(treasury), 0.5 ether);

            console.log(treasury.weth().balanceOf(address(treasury)));

            treasury.setMinSweepAmount(0.1 ether);

            // emit EpochSwept(epochIndex);
            treasury.sweepEpoch(0, address(manualSweeper), '', 0);
        }

        /**
         * src/contracts/strategies/NFTXLiquidityPoolStakingStrategy.sol
         * src/contracts/strategies/UniswapV3Strategy.sol
         * src/contracts/strategies/DistributedRevenueStakingStrategy.sol
         * src/contracts/strategies/NFTXInventoryStakingStrategy.sol
         * src/contracts/strategies/RevenueStakingStrategy.sol
         */

        // emit Withdraw(underlyingToken, amount_, msg.sender);
        // emit Harvest(yieldToken, amounts[0]);
        // emit Deposit(token, amount, msg.sender);


        /**
         * src/contracts/triggers/StoreEpochCollectionVotes.sol
         */

        // emit EpochVotesSnapshot(epoch, collectionAddrs, collectionVotes);


        /**
         * src/contracts/migrations/MigrateTreasury.sol
         */

        // emit TokenMigrated(address(token), received, sent);


        /**
         * src/contracts/migrations/MigrateFloorToken.sol
         */

        // emit FloorMigrated(msg.sender, floorAllocation);


        /**
         * src/contracts/collections/CollectionRegistry.sol
         */

        console.log('COLLECTION UNAPPROVE');

        // emit CollectionRevoked(contractAddr);
        CollectionRegistry collectionRegistry = CollectionRegistry(requireDeployment('CollectionRegistry'));
        collectionRegistry.unapproveCollection(address(erc721Mock));


        /**
         * Unhandled
         */

        // ~/Sites/floor-v2/src/contracts/sweepers/CowSwap.sol:
        // emit OrderPlacement(address(instance), order, signature, '');

    }

    /**
     * Allows the contract to receive ERC1155 tokens.
     */
    function onERC1155Received(address, address, uint, uint, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * Allows the contract to receive batch ERC1155 tokens.
     */
    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * GET CASH MONEY FAM!
     */
    receive() payable external {}

    function _strategyData() internal pure returns (bytes memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = 0x269616D549D7e8Eaa82DFb17028d0B212D11232A;

        return abi.encode(tokens);
    }

}
