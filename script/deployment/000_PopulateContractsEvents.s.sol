// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20Mock} from '../../test/mocks/erc/ERC20Mock.sol';
import {ERC721Mock} from '../../test/mocks/erc/ERC721Mock.sol';
import {ERC1155Mock} from '../../test/mocks/erc/ERC1155Mock.sol';

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
import {NFTXInventoryStakingStrategy} from '@floor/strategies/NFTXInventoryStakingStrategy.sol';
import {Treasury} from '@floor/Treasury.sol';

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

        // Set up a mock erc20
        ERC20Mock erc20Mock = new ERC20Mock();
        ERC721Mock erc721Mock = ERC721Mock(0xDc110028492D1baA15814fCE939318B6edA13098);
        ERC1155Mock erc1155Mock = new ERC1155Mock();

        // Set some test tokens to our user
        uint erc721TokenId = 0;
        uint erc1155TokenId = 0;

        // Mint some tokens
        erc721Mock.mint(address(this), erc721TokenId);
        erc1155Mock.mint(address(this), erc1155TokenId, 5, '');

        // Deploy an action we can run
        SendEth action = new SendEth();

        // Load our manual sweeper
        ManualSweeper manualSweeper;

        // Load our base strategy
        NFTXInventoryStakingStrategy strategy;

        // Secure test address
        address testAddress = 0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96; // twade.eth


        /**
         * src/contracts/Treasury.sol
         */

        Treasury treasury = Treasury(requireDeployment('Treasury'));

        {
            // emit FloorMinted(amount);
            treasury.mint(10 ether);

            // Approve FLOOR token and NFTs to be used by Treasury
            treasury.floor().approve(address(treasury), type(uint).max);
            erc721Mock.approve(address(treasury), erc721TokenId);
            erc1155Mock.setApprovalForAll(address(treasury), true);

            // emit Deposit(msg.value);
            (bool sent,) = address(treasury).call{value: 1 ether}('');
            require(sent);

            // emit DepositERC20(token, amount);
            treasury.depositERC20(address(treasury.floor()), 1 ether);

            // emit DepositERC721(token, tokenId);
            treasury.depositERC721(address(erc721Mock), erc721TokenId);

            // emit DepositERC1155(token, tokenId, amount);
            treasury.depositERC1155(address(erc1155Mock), erc1155TokenId, 2);

            // emit Withdraw(amount, recipient);
            treasury.withdraw(address(this), 1 ether);

            // emit WithdrawERC20(token, amount, recipient);
            treasury.withdrawERC20(address(this), address(treasury.floor()), 1 ether);

            // emit WithdrawERC721(token, tokenId, recipient);
            treasury.withdrawERC721(address(this), address(erc721Mock), erc721TokenId);

            // emit WithdrawERC1155(token, tokenId, amount, recipient);
            treasury.withdrawERC1155(address(this), address(erc1155Mock), erc1155TokenId, 2);

            // emit SweepRegistered(epoch, sweepType, collections, amounts);
            address[] memory _collections = new address[](2);
            _collections[0] = address(1);
            _collections[1] = address(2);
            uint[] memory _amounts = new uint[](2);
            _amounts[0] = 1 ether;
            _amounts[1] = 2 ether;

            treasury.registerSweep(0, _collections, _amounts, TreasuryEnums.SweepType.SWEEP);

            // emit ActionProcessed(action, data);
            // emit SweepAction(linkedSweepEpoch);
            ITreasury.ActionApproval[] memory approvals = new ITreasury.ActionApproval[](1);
            approvals[0] = ITreasury.ActionApproval(
                TreasuryEnums.ApprovalType.NATIVE, // Token type
                address(0), // address assetContract
                0, // uint tokenId
                0.01 ether // uint amount
            );

            treasury.processAction(payable(address(action)), approvals, abi.encode(address(this), 0.01 ether), 0);
        }


        /**
         * src/contracts/RageQuit.sol
         */

        {
            RageQuit rageQuit = RageQuit(requireDeployment('RageQuit'));

            // emit FundsAdded(token, amount);
            rageQuit.fund(address(erc20Mock), 1 ether);

            // emit Paperboy(msg.sender, amount);
            rageQuit.ragequit(1 ether);
        }


        /**
         * src/contracts/authorities/AuthorityRegistry.sol
         */

        {
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
            staking.deposit(1 ether, 1);

            // emit Withdraw(msg.sender, balance);
            staking.earlyWithdraw(0, 1 ether);
        }


        /**
         * src/contracts/voting/NewCollectionWars.sol
         */

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
            SweepWars sweepWars = SweepWars(requireDeployment('SweepWars'));

            // emit VoteCast(msg.sender, _collection, _amount);
            // Must have staked balance
            sweepWars.vote(address(erc721Mock), 1 ether);

            // emit VotesRevoked(_account, _collections[i], userForVotes[collectionHash], userAgainstVotes[collectionHash]);
            address[] memory _collections = new address[](1);
            _collections[0] = address(erc721Mock);
            sweepWars.revokeVotes(_collections);
        }


        /**
         * src/contracts/strategies/StrategyFactory.sol
         */

        {
            StrategyFactory strategyFactory = StrategyFactory(requireDeployment('StrategyFactory'));

            // emit StrategyCreated(strategyId_, strategyAddr_, _collection);
            (uint strategyId_,) = strategyFactory.deployStrategy(
                'Mock Strategy',
                address(strategy),
                abi.encode(''),
                address(erc721Mock)
            );

            // emit StrategySnapshot(_epoch, _strategyId, tokens, amounts);
            strategyFactory.snapshot(strategyId_, 1);
        }


        /**
         * src/contracts/EpochManager.sol
         */

        {
            EpochManager epochManager = EpochManager(requireDeployment('EpochManager'));

            // emit CollectionAdditionWarScheduled(epoch, index);
            // TODO: Must be fired by new collection war in the `createFloorWar` function

            // emit EpochEnded(currentEpoch, lastEpoch);
            epochManager.endEpoch();
        }


        /**
         * src/contracts/voting/NewCollectionWars.sol
         */

        {
            // emit VoteCast(msg.sender, collection, userVotes[warUser], collectionVotes[warCollection]);
            newCollectionWars.vote(address(erc721Mock));

            // emit VoteRevoked(msg.sender, collection, collectionVotes[warCollection]);
            newCollectionWars.revokeVotes(address(this));

            // emit NftVoteCast(sender, war, collection, collectionVotes[warCollection], collectionNftVotes[warCollection]);
            newCollectionWars.setOptionsContract(address(this));
            newCollectionWars.optionVote(address(this), 1, address(erc721Mock), 1 ether);
            newCollectionWars.setOptionsContract(address(0));
        }


        /**
         * src/contracts/Treasury.sol
         */

        {
            // emit EpochSwept(epochIndex);
            treasury.sweepEpoch(0, address(manualSweeper), '', 0);
        }

        /**
         * src/contracts/strategies/NFTXLiquidityPoolStakingStrategy.sol
         */

        // emit Withdraw(underlyingToken, amount_, msg.sender);

        // emit Harvest(yieldToken, amounts[0]);

        // emit Deposit(token, amount, msg.sender);


        /**
         * src/contracts/strategies/UniswapV3Strategy.sol
         */

        // emit Deposit(params.token1, amount1, msg.sender);

        // emit Withdraw(params.token0, amount0Collected, recipient);

        // emit Harvest(params.token0, amount0);


        /**
         * src/contracts/strategies/DistributedRevenueStakingStrategy.sol
         */

        // emit Deposit(_tokens[0], amount, msg.sender);

        // emit Harvest(_tokens[0], amount);

        // emit Withdraw(_tokens[0], amount, recipient);


        /**
         * src/contracts/strategies/NFTXInventoryStakingStrategy.sol
         */

        // emit Withdraw(underlyingToken, amount_, recipient);

        // emit Harvest(yieldToken, amounts[0]);

        // emit Deposit(token, amount, msg.sender);

        /**
         * src/contracts/strategies/RevenueStakingStrategy.sol
         */

        // emit Deposit(token, amount, msg.sender);


        // emit Harvest(token, amount);


        // emit Withdraw(token, amount, recipient);


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

}
