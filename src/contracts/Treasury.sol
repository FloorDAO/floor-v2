// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {ERC1155Holder} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import {AuthorityControl} from '@floor/authorities/AuthorityControl.sol';
import {FLOOR} from '@floor/tokens/Floor.sol';
import {CannotSetNullAddress, InsufficientAmount, PercentageTooHigh, TransferFailed} from '@floor/utils/Errors.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';
import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';
import {ICollectionRegistry} from '@floor-interfaces/collections/CollectionRegistry.sol';
import {IBasePricingExecutor} from '@floor-interfaces/pricing/BasePricingExecutor.sol';
import {IBaseStrategy} from '@floor-interfaces/strategies/BaseStrategy.sol';
import {IStrategyRegistry} from '@floor-interfaces/strategies/StrategyRegistry.sol';
import {IVault} from '@floor-interfaces/vaults/Vault.sol';
import {IVaultFactory} from '@floor-interfaces/vaults/VaultFactory.sol';
import {IGaugeWeightVote} from '@floor-interfaces/voting/GaugeWeightVote.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/// If the epoch is currently timelocked and insufficient time has passed.
/// @param timelockExpiry The timestamp at which the epoch can next be run
error EpochTimelocked(uint timelockExpiry);

/// If not pricing executor has been set before a call that requires it
error NoPricingExecutorSet();

/**
 * The Treasury will hold all assets.
 */
contract Treasury is AuthorityControl, ERC1155Holder, ITreasury {
    /// ..
    enum ApprovalType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155
    }

    /**
     * ..
     */
    struct Sweep {
        address[] collections;
        uint[] amounts;
        uint allocationBlock;
        uint sweepBlock;
        bool completed;
    }

    /// An array of sweeps that map against the epoch iteration
    mapping(uint => Sweep) public epochSweeps;

    /**
     * ..
     */
    struct ActionApproval {
        ApprovalType _type; // Token type
        address assetContract; // Used by 20, 721 and 1155
        uint tokenId; // Used by 721 tokens
        uint amount; // Used by native and 20 tokens
    }

    /// Store when last epoch was run so that we can timelock usage
    uint public lastEpoch;
    uint public EPOCH_LENGTH = 7 days;

    /// Store our epoch iteration number
    uint public epochIteration;

    /// Holds our {StrategyRegistry} contract reference
    IStrategyRegistry public strategyRegistry;

    /// Holds our {CollectionRegistry} contract reference
    ICollectionRegistry public collectionRegistry;

    /// Holds our {VaultFactory} contract reference
    IVaultFactory public vaultFactory;

    /// Holds our {FLOOR} contract reference
    FLOOR public floor;

    /// The current pricing executor contract
    IBasePricingExecutor public pricingExecutor;

    /// The amount of our {Treasury} reward yield that is retained. Any remaining percentage
    /// amount will be distributed to the top voted collections via our {GaugeWeightVote} contract.
    uint public retainedTreasuryYieldPercentage;

    /// Our Gauge Weight Voting contract
    IGaugeWeightVote public voteContract;

    /// Store our token prices, set by our `pricingExecutor`
    mapping(address => uint) public tokenEthPrice;

    /// Store a minimum sweep amount that can be implemented, or excluded, as desired by
    /// the DAO.
    uint public minSweepAmount;

    /**
     * Set up our connection to the Treasury to ensure future calls only come from this
     * trusted source.
     *
     * @param _authority {AuthorityRegistry} contract address
     * @param _collectionRegistry Address of our {CollectionRegistry}
     * @param _strategyRegistry Address of our {StrategyRegistry}
     * @param _vaultFactory Address of our {VaultFactory}
     * @param _floor Address of our {FLOOR}
     */
    constructor(address _authority, address _collectionRegistry, address _strategyRegistry, address _vaultFactory, address _floor)
        AuthorityControl(_authority)
    {
        collectionRegistry = ICollectionRegistry(_collectionRegistry);
        strategyRegistry = IStrategyRegistry(_strategyRegistry);
        vaultFactory = IVaultFactory(_vaultFactory);
        floor = FLOOR(_floor);
    }

    /**
     * Distributes reward tokens to the {VaultXToken}, sending the FLOOR token to each instance
     * based on the amount of reward yield that has been generated.
     *
     *  - If the reward is from treasury yield, then the recipient is based on GWV
     *  - If the reward is from staker yield, then it will be allocated to user in the {VaultXToken}
     *
     * When a token deposit from strategy reward yield comes in, we can find the matching vault and
     * find the holdings of all users. The treasury user is a special case, but the others will have
     * a holding percentage determined for their reward share. Only users that are eligible (see note
     * below on rewards cycle) will have their holdings percentage calculated. This holdings
     * percentage will get them FLOOR rewards of all non-treasury yield, plus non-retained treasury
     * yield based on {setRetainedTreasuryYieldPercentage}.
     *
     * As an example, consider the following scenario:
     *
     * +----------------+-----------------+-------------------+
     * | Staker         | Amount          | Percent           |
     * +----------------+-----------------+-------------------+
     * | Alice          | 30              | 30%               |
     * | Bob            | 10              | 10%               |
     * | Treasury       | 60              | 60%               |
     * +----------------+-----------------+-------------------+
     *
     * Say the strategy collects 10 tokens in reward in this cycle, and all staked parties are
     * eligible to receive their reward allocation. The GWV in this example is attributing 40% to
     * the example vault and we assume a FLOOR to token ratio of 5:1 (5 FLOOR is minted for each
     * reward token in treasury). We are also assuming that we are retaining 50% of treasury rewards.
     *
     * The Treasury in this instance would be allocated 6 reward tokens (as they hold 60% of the vault
     * share) and would convert 50% of this reward yield to FLOOR (due to 50% retention). This means
     * that 3 of the reward tokens would generate an additional 15 FLOOR, distributed to non-Treasry
     * holders, giving a total of 35.
     *
     * +----------------+--------------------+
     * | Staker         | FLOOR Rewards      |
     * +----------------+--------------------+
     * | Alice          | 26.25              |
     * | Bob            | 8.75               |
     * | Treasury       | 0                  |
     * +----------------+--------------------+
     *
     * And gives us a treasury updated holding of:
     *
     * +----------------+--------------------+
     * | Token          | Amount             |
     * +----------------+--------------------+
     * | FLOOR          | 0                  |
     * | Reward Token   | 10                 |
     * +----------------+--------------------+
     *
     * A user will only be eligible if they have been staked for a complete rewards epoch.
     */
    function endEpoch() external {
        // Ensure enough time has past since the last epoch ended
        if (lastEpoch != 0 && block.timestamp < lastEpoch + EPOCH_LENGTH) {
            revert EpochTimelocked(lastEpoch + EPOCH_LENGTH);
        }

        // Get our vaults
        address[] memory vaults = vaultFactory.vaults();

        // Get the prices of our approved collections
        getCollectionEthPrices();

        // Store the amount of rewards generated in ETH
        uint ethRewards;

        // Create our variables that we will reallocate during our loop to save gas
        IVault vault;
        uint vaultId;
        uint vaultYield;

        // Iterate over vaults
        for (uint i; i < vaults.length;) {
            // Parse our vault address into the Vault interface
            vault = IVault(vaults[i]);

            // Pull out rewards and transfer into the {Treasury}
            vaultId = vault.vaultId();
            vaultYield = vaultFactory.claimRewards(vaultId);

            if (vaultYield != 0) {
                // Calculate the reward yield in FLOOR token terms
                unchecked {
                    ethRewards += tokenEthPrice[vault.collection()] * vaultYield;
                }

                // Now that the {Treasury} has knowledge of the reward tokens and has minted
                // the equivalent FLOOR, we can notify the {Strategy} and transfer assets into
                // the {Treasury}.
                vaultFactory.registerMint(vaultId, vaultYield);
            }

            unchecked {
                ++i;
            }
        }

        unchecked {
            epochIteration += 1;
            lastEpoch = block.timestamp;
        }

        // Confirm we are not retaining all yield
        if (ethRewards != 0 && retainedTreasuryYieldPercentage != 10000) {
            // Determine the total amount of snapshot tokens. This should be calculated as all
            // of the `publicFloorYield`, as well as {100 - `retainedTreasuryYieldPercentage`}%
            // of the treasuryFloorYield.
            uint sweepAmount = (ethRewards * (10000 - retainedTreasuryYieldPercentage)) / 10000;

            // We want the ability to set a minimum sweep amount, so that when we are first
            // starting out the sweeps aren't pathetic.
            if (minSweepAmount != 0 && sweepAmount < minSweepAmount) {
                sweepAmount = minSweepAmount;
            }

            // Process the snapshot, which will reward xTokens holders directly
            (address[] memory collections, uint[] memory amounts) = voteContract.snapshot(sweepAmount, epochIteration);

            // Now that we have the results of the snapshot we can register them against our
            // pending sweeps.
            epochSweeps[epochIteration] =
                Sweep({collections: collections, amounts: amounts, allocationBlock: block.number, sweepBlock: 0, completed: false});
        }

        // emit EpochEnded(lastEpoch);
    }

    /**
     * Allow FLOOR token to be minted. This should be called from the deposit method
     * internally, but a public method will allow a {TreasuryManager} to bypass this
     * and create additional FLOOR tokens if needed.
     *
     * @param amount The amount of {FLOOR} tokens to be minted
     */
    function mint(uint amount) external onlyRole(TREASURY_MANAGER) {
        if (amount == 0) {
            revert InsufficientAmount();
        }

        _mint(address(this), amount);
    }

    /**
     * Internal call to handle minting and event firing.
     *
     * @param recipient The recipient of the {FLOOR} tokens
     * @param amount The number of tokens to be minted
     */
    function _mint(address recipient, uint amount) internal {
        floor.mint(recipient, amount);
        emit FloorMinted(amount);
    }

    /**
     * Allows an ERC20 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     *
     * @param token ERC20 token address to be deposited
     * @param amount The amount of the token to be deposited
     */
    function depositERC20(address token, uint amount) external {
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }

        emit DepositERC20(token, amount);
    }

    /**
     * Allows an ERC721 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     *
     * @param token ERC721 token address to be deposited
     * @param tokenId The ID of the ERC721 being deposited
     */
    function depositERC721(address token, uint tokenId) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        emit DepositERC721(token, tokenId);
    }

    /**
     * Allows an ERC1155 token(s) to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     *
     * @param token ERC1155 token address to be deposited
     * @param tokenId The ID of the ERC1155 being deposited
     * @param amount The amount of the token to be deposited
     */
    function depositERC1155(address token, uint tokenId, uint amount) external {
        IERC1155(token).safeTransferFrom(msg.sender, address(this), tokenId, amount, '');
        emit DepositERC1155(token, tokenId, amount);
    }

    /**
     * Allows an approved user to withdraw native token.
     *
     * @param recipient The user that will receive the native token
     * @param amount The number of native tokens to withdraw
     */
    function withdraw(address recipient, uint amount) external onlyRole(TREASURY_MANAGER) {
        (bool success,) = recipient.call{value: amount}('');
        if (!success) {
            revert TransferFailed();
        }

        emit Withdraw(amount, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC20 token from the vault.
     *
     * @param recipient The user that will receive the ERC20 tokens
     * @param token ERC20 token address to be withdrawn
     * @param amount The number of tokens to withdraw
     */
    function withdrawERC20(address recipient, address token, uint amount) external onlyRole(TREASURY_MANAGER) {
        bool success = IERC20(token).transfer(recipient, amount);
        if (!success) {
            revert TransferFailed();
        }

        emit WithdrawERC20(token, amount, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC721 token from the vault.
     *
     * @param recipient The user that will receive the ERC721 tokens
     * @param token ERC721 token address to be withdrawn
     * @param tokenId The ID of the ERC721 being withdrawn
     */
    function withdrawERC721(address recipient, address token, uint tokenId) external onlyRole(TREASURY_MANAGER) {
        IERC721(token).transferFrom(address(this), recipient, tokenId);
        emit WithdrawERC721(token, tokenId, recipient);
    }

    /**
     * Allows an approved user to withdraw an ERC1155 token(s) from the vault.
     *
     * @param recipient The user that will receive the ERC1155 tokens
     * @param token ERC1155 token address to be withdrawn
     * @param tokenId The ID of the ERC1155 being withdrawn
     * @param amount The number of tokens to withdraw
     */
    function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external onlyRole(TREASURY_MANAGER) {
        IERC1155(token).safeTransferFrom(address(this), recipient, tokenId, amount, '');
        emit WithdrawERC1155(token, tokenId, amount, recipient);
    }

    /**
     * Allows the GWV contract address to be set.
     *
     * @param contractAddr Address of new {GaugeWeightVote} contract
     */
    function setGaugeWeightVoteContract(address contractAddr) external onlyRole(TREASURY_MANAGER) {
        if (contractAddr == address(0)) {
            revert CannotSetNullAddress();
        }

        voteContract = IGaugeWeightVote(contractAddr);
    }

    /**
     * Sets the percentage of treasury rewards yield to be retained by the treasury, with
     * the remaining percetange distributed to non-treasury vault stakers based on the GWV.
     *
     * @param percent New treasury yield percentage value
     */
    function setRetainedTreasuryYieldPercentage(uint percent) external onlyRole(TREASURY_MANAGER) {
        if (percent > 10000) {
            revert PercentageTooHigh(10000);
        }

        retainedTreasuryYieldPercentage = percent;
    }

    /**
     * Updates our FLOOR <-> token price mapping to determine the amount of FLOOR to allocate
     * as user rewards.
     *
     * The vault will handle its own internal price calculation and stale caching logic based
     * on a {VaultPricingStrategy} tied to the vault.
     *
     * @dev Our FLOOR ETH price is determined by:
     * https://app.uniswap.org/#/swap?outputCurrency=0xf59257E961883636290411c11ec5Ae622d19455e&inputCurrency=ETH&chain=Mainnet
     *
     * Our token ETH price is determined by (e.g. PUNK):
     * https://app.uniswap.org/#/swap?outputCurrency=0xf59257E961883636290411c11ec5Ae622d19455e&inputCurrency=ETH&chain=Mainnet
     */
    function getCollectionEthPrices() public {
        if (address(pricingExecutor) == address(0)) {
            revert NoPricingExecutorSet();
        }

        // Get our approved collections
        address[] memory collections = collectionRegistry.approvedCollections();

        // Query our pricing executor to get our floor price equivalent
        uint[] memory tokenEthPrices = pricingExecutor.getETHPrices(collections);

        // Iterate through our list and store it to our internal mapping
        for (uint i; i < tokenEthPrices.length;) {
            tokenEthPrice[collections[i]] = tokenEthPrices[i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Sets an updated pricing executor (needs to confirm an implementation function).
     *
     * @param contractAddr Address of new {IBasePricingExecutor} contract
     */
    function setPricingExecutor(address contractAddr) external onlyRole(TREASURY_MANAGER) {
        if (contractAddr == address(0)) {
            revert CannotSetNullAddress();
        }

        pricingExecutor = IBasePricingExecutor(contractAddr);
    }

    /**
     * Apply an action against the vault.
     *
     * @param action Address of the action to apply
     * @param approvals Any tokens that need to be approved before actioning
     * @param data Any bytes data that should be passed to the {IAction} execution function
     */
    function processAction(address payable action, ActionApproval[] memory approvals, bytes memory data)
        external
        onlyRole(TREASURY_MANAGER)
    {
        for (uint i; i < approvals.length;) {
            if (approvals[i]._type == ApprovalType.NATIVE) {
                (bool sent,) = payable(action).call{value: approvals[i].amount}('');
                require(sent, 'Unable to fund action');
            } else if (approvals[i]._type == ApprovalType.ERC20) {
                IERC20(approvals[i].assetContract).approve(action, approvals[i].amount);
            } else if (approvals[i]._type == ApprovalType.ERC721) {
                IERC721(approvals[i].assetContract).approve(action, approvals[i].tokenId);
            } else if (approvals[i]._type == ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(action, true);
            }

            unchecked {
                ++i;
            }
        }

        IAction(action).execute(data);

        // Remove ERC1155 global approval after execution
        for (uint i; i < approvals.length;) {
            if (approvals[i]._type == ApprovalType.ERC1155) {
                IERC1155(approvals[i].assetContract).setApprovalForAll(action, false);
            }
        }
    }

    /**
     * ..
     */
    function sweepEpoch(uint epochIndex, address sweeper) public onlyRole(TREASURY_MANAGER) {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have a valid sweep index
        require(!epochSweep.completed, 'Epoch sweep already completed');
        require(epochSweep.collections.length != 0, 'No collections to sweep');

        return _sweepEpoch(epochIndex, sweeper, epochSweep);
    }

    /**
     * ..
     */
    function resweepEpoch(uint epochIndex, address sweeper) public onlyRole(TREASURY_MANAGER) {
        // Load the stored sweep at our epoch index
        Sweep memory epochSweep = epochSweeps[epochIndex];

        // Ensure we have a valid sweep index
        require(epochSweep.collections.length != 0, 'No collections to sweep');

        return _sweepEpoch(epochIndex, sweeper, epochSweep);
    }

    /**
     * ..
     */
    function setMinSweepAmount(uint _minSweepAmount) external onlyRole(TREASURY_MANAGER) {
        minSweepAmount = _minSweepAmount;
    }

    /**
     * ..
     */
    function _sweepEpoch(uint epochIndex, address sweeper, Sweep memory epochSweep) internal {
        // Find the total amount to send to the sweeper and transfer it before the call
        uint msgValue;
        for (uint i; i < epochSweep.collections.length;) {
            unchecked {
                msgValue += epochSweep.amounts[i];
                ++i;
            }
        }

        // Action our sweep. If we don't hold enough ETH to supply the message value then
        // we expect this call to revert.
        ISweeper(sweeper).execute{value: msgValue}(epochSweep.collections, epochSweep.amounts);

        // Mark our sweep as completed
        epochSweep.completed = true;
        epochSweep.sweepBlock = block.number;

        epochSweeps[epochIndex] = epochSweep;

        // emit EpochSwept(epochIndex);
    }

    /**
     * ..
     */
    function epochIterationTimestamp(uint _epochIteration) public view returns (uint) {
        if (epochIteration < _epochIteration) {
            return lastEpoch + (_epochIteration * EPOCH_LENGTH);
        }

        if (epochIteration == _epochIteration) {
            return lastEpoch;
        }

        return lastEpoch - (_epochIteration * EPOCH_LENGTH);
    }

    /**
     * Allow our contract to receive native tokens.
     */
    receive() external payable {
        emit Deposit(msg.value);
    }
}
