/**
 * Reward token has EIP-2612 (https://eips.ethereum.org/EIPS/eip-2612)
 *
 * Based on:
 * https://stakedao.gitbook.io/stakedaohq/platform/votemarket/votemarket-contracts
 *
 * Factory to create a "BribePool"
 *
 * A BribePool allows a pool to be set up with:
 *  - Collection (or FLOOR) address
 *  - Reward token address
 *  - Total reward allocation for all epochs (split evenly)
 *  - Number of epochs to run for
 *  - Max token reward per veFLOOR
 *
 * - Ability to blacklist addresses
 * - Finalise the vault to prevent updates
 * - Reward token is transferred into the pool
 *
 * - External party can then vote (deposit their veFLOOR into contract)
 * - External party can claim after an epoch has passed
 * - veFLOOR is locked for a set number of epochs
 * - veFLOOR can only be withdrawn when epoch count has been reached
 *
 * - A fee can be set to ensure that FLOOR receives some of the token yield
 *
 * - Fee dispersal can be done through a claim contract similar to dividend token. We will
 *   have the full allocation in the contract from the start, so it is ready to claim
 *   straight away.
 *
 * - Do we want the bribe initiator to get a small cut of the fee?
 * - What fee amount would we want?
 */

contract FeeManager is Owned {
    using SafeTransferLib for ERC20;
    uint256 public totalFee;
    uint256 internal constant _DEFAULT_FEE = 2e16; // 2%
    struct FeeRecipient {
        address recipient;
        uint256 fee;
    }
    FeeRecipient[] public recipients;

    /// @notice Thrown if the fee percentage is invalid.
    error INCORRECT_FEE();

    constructor(address _feeRecipient) Owned(_feeRecipient) {
        totalFee = _DEFAULT_FEE;
        recipients.push(FeeRecipient(_feeRecipient, _DEFAULT_FEE));
    }

    function disperseFees(address _token) external {
        uint256 length = recipients.length;
        uint256 totalBal = ERC20(_token).balanceOf(address(this));
        uint256 amount;
        for (uint256 i; i < length; ) {
            FeeRecipient memory recipient = recipients[i];
            amount = (totalBal * recipient.fee) / totalFee;
            ERC20(_token).safeTransfer(recipient.recipient, amount);
            unchecked {
                i++;
            }
        }
    }

    function addRecipient(address _recipient, uint256 _fee) external onlyOwner {
        if (_fee > 1e18) revert INCORRECT_FEE();
        recipients.push(FeeRecipient(_recipient, _fee));
        totalFee += _fee;
    }

    function removeRecipient(uint256 _index) external onlyOwner {
        totalFee -= recipients[_index].fee;
        recipients[_index] = recipients[recipients.length - 1];
        recipients.pop();
    }

    function updateRecipient(
        uint256 _index,
        address _recipient,
        uint256 _fee
    ) external onlyOwner {
        if (_fee > 1e18) revert INCORRECT_FEE();
        totalFee -= recipients[_index].fee;
        recipients[_index].recipient = _recipient;
        recipients[_index].fee = _fee;
        totalFee += _fee;
    }

    function totalFeeRecipients() external view returns (uint256) {
        return recipients.length;
    }
}

/// version 1.5.0
/// @title  Platform
/// @author Stake DAO
contract Platform is ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    ////////////////////////////////////////////////////////////////
    /// --- EMERGENCY SHUTDOWN
    ///////////////////////////////////////////////////////////////

    /// @notice Emergency shutdown flag
    bool public isKilled;

    ////////////////////////////////////////////////////////////////
    /// --- STRUCTS
    ///////////////////////////////////////////////////////////////

    /// @notice Bribe struct requirements.
    struct Bribe {
        // Address of the target gauge.
        address gauge;
        // Manager.
        address manager;
        // Address of the ERC20 used for rewards.
        address rewardToken;
        // Number of periods.
        uint8 numberOfPeriods;
        // Timestamp where the bribe become unclaimable.
        uint256 endTimestamp;
        // Max Price per vote.
        uint256 maxRewardPerVote;
        // Total Reward Added.
        uint256 totalRewardAmount;
        // Blacklisted addresses.
        address[] blacklist;
    }

    /// @notice Period struct.
    struct Period {
        // Period id.
        // Eg: 0 is the first period, 1 is the second period, etc.
        uint8 id;
        // Timestamp of the period start.
        uint256 timestamp;
        // Reward amount distributed during the period.
        uint256 rewardPerPeriod;
    }

    struct Upgrade {
        // Number of periods after increase.
        uint8 numberOfPeriods;
        // Total reward amount after increase.
        uint256 totalRewardAmount;
        // New max reward per vote after increase.
        uint256 maxRewardPerVote;
        // New end timestamp after increase.
        uint256 endTimestamp;
        // Blacklisted addresses.
        address[] blacklist;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Week in seconds.
    uint256 private constant _WEEK = 1 weeks;

    /// @notice Base unit for fixed point compute.
    uint256 private constant _BASE_UNIT = 1e18;

    /// @notice Minimum duration a Bribe.
    uint8 public constant MINIMUM_PERIOD = 2;

    /// @notice Factory contract.
    Factory public immutable factory;

    /// @notice Gauge Controller.
    GaugeController public immutable gaugeController;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARS
    ///////////////////////////////////////////////////////////////

    /// @notice Bribe ID Counter.
    uint256 public nextID;

    /// @notice ID => Bribe.
    mapping(uint256 => Bribe) public bribes;

    /// @notice ID => Bribe In Queue to be upgraded.
    mapping(uint256 => Upgrade) public upgradeBribeQueue;

    /// @notice ID => Period running.
    mapping(uint256 => Period) public activePeriod;

    /// @notice BribeId => isUpgradeable. If true, the bribe can be upgraded.
    mapping(uint256 => bool) public isUpgradeable;

    /// @notice ID => Amount Claimed per Bribe.
    mapping(uint256 => uint256) public amountClaimed;

    /// @notice ID => Amount of reward per vote distributed.
    mapping(uint256 => uint256) public rewardPerVote;

    /// @notice Blacklisted addresses per bribe that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// @notice Last time a user claimed
    mapping(address => mapping(uint256 => uint256)) public lastUserClaim;

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyManager(uint256 _id) {
        if (msg.sender != bribes[_id].manager) revert AUTH_MANAGER_ONLY();
        _;
    }

    modifier notKilled() {
        if (isKilled) revert KILLED();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// --- EVENTS
    ///////////////////////////////////////////////////////////////

    /// @notice Emitted when a new bribe is created.
    event BribeCreated(
        uint256 indexed id,
        address indexed gauge,
        address manager,
        address indexed rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 rewardPerPeriod,
        uint256 totalRewardAmount,
        bool isUpgradeable
    );

    /// @notice Emitted when a bribe is closed.
    event BribeClosed(uint256 id, uint256 remainingReward);

    /// @notice Emitted when a bribe period is rolled over.
    event PeriodRolledOver(
        uint256 id,
        uint256 periodId,
        uint256 timestamp,
        uint256 rewardPerPeriod
    );

    /// @notice Emitted on claim.
    event Claimed(
        address indexed user,
        address indexed rewardToken,
        uint256 indexed bribeId,
        uint256 amount,
        uint256 protocolFees,
        uint256 period
    );

    /// @notice Emitted when a bribe is queued to upgrade.
    event BribeDurationIncreaseQueued(
        uint256 id,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bribe is upgraded.
    event BribeDurationIncreased(
        uint256 id,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bribe manager is updated.
    event ManagerUpdated(uint256 id, address indexed manager);

    ////////////////////////////////////////////////////////////////
    /// --- ERRORS
    ///////////////////////////////////////////////////////////////

    error KILLED();
    error WRONG_INPUT();
    error ZERO_ADDRESS();
    error NO_PERIODS_LEFT();
    error NOT_UPGRADEABLE();
    error AUTH_MANAGER_ONLY();
    error ALREADY_INCREASED();
    error NOT_ALLOWED_OPERATION();
    error INVALID_NUMBER_OF_PERIODS();

    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bribe platform.
    /// @param _gaugeController Address of the gauge controller.
    constructor(address _gaugeController, address _factory) {
        factory = Factory(_factory);
        gaugeController = GaugeController(_gaugeController);
    }

    ////////////////////////////////////////////////////////////////
    /// --- BRIBE CREATION LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Create a new bribe.
    /// @param gauge Address of the target gauge.
    /// @param rewardToken Address of the ERC20 used or rewards.
    /// @param numberOfPeriods Number of periods.
    /// @param maxRewardPerVote Target Bias for the Gauge.
    /// @param totalRewardAmount Total Reward Added.
    /// @param blacklist Array of addresses to blacklist.
    /// @return newBribeID of the bribe created.
    function createBribe(
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata blacklist,
        bool upgradeable
    ) external nonReentrant notKilled returns (uint256 newBribeID) {
        if (rewardToken == address(0)) revert ZERO_ADDRESS();
        if (gaugeController.gauge_types(gauge) < 0) return newBribeID;
        if (numberOfPeriods < MINIMUM_PERIOD)
            revert INVALID_NUMBER_OF_PERIODS();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0)
            revert WRONG_INPUT();

        // Transfer the rewards to the contracts.
        ERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            totalRewardAmount
        );

        unchecked {
            // Get the ID for that new Bribe and increment the nextID counter.
            newBribeID = nextID;

            ++nextID;
        }

        uint256 rewardPerPeriod = totalRewardAmount.mulDivDown(
            1,
            numberOfPeriods
        );
        uint256 currentPeriod = getCurrentPeriod();

        bribes[newBribeID] = Bribe({
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            endTimestamp: currentPeriod + ((numberOfPeriods + 1) * _WEEK),
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            blacklist: blacklist
        });

        emit BribeCreated(
            newBribeID,
            gauge,
            manager,
            rewardToken,
            numberOfPeriods,
            maxRewardPerVote,
            rewardPerPeriod,
            totalRewardAmount,
            upgradeable
        );

        // Set Upgradeable status.
        isUpgradeable[newBribeID] = upgradeable;
        // Starting from next period.
        activePeriod[newBribeID] = Period(
            0,
            currentPeriod + _WEEK,
            rewardPerPeriod
        );

        // Add the addresses to the blacklist.
        uint256 length = blacklist.length;
        for (uint256 i = 0; i < length; ) {
            isBlacklisted[newBribeID][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim rewards for a given bribe.
    /// @param bribeId ID of the bribe.
    /// @return Amount of rewards claimed.
    function claimFor(address user, uint256 bribeId)
        external
        returns (uint256)
    {
        address recipient = factory.recipient(user, address(gaugeController));
        return
            _claim(user, recipient != address(0) ? recipient : user, bribeId);
    }

    function claimAllFor(address user, uint256[] calldata ids) external {
        address recipient = factory.recipient(user, address(gaugeController));
        uint256 length = ids.length;

        for (uint256 i = 0; i < length; ) {
            uint256 id = ids[i];
            _claim(user, recipient != address(0) ? recipient : user, id);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim rewards for a given bribe.
    /// @param bribeId ID of the bribe.
    /// @return Amount of rewards claimed.
    function claim(uint256 bribeId) external returns (uint256) {
        address recipient = factory.recipient(
            msg.sender,
            address(gaugeController)
        );
        return
            _claim(
                msg.sender,
                recipient != address(0) ? recipient : msg.sender,
                bribeId
            );
    }

    /// @notice Update Bribe for a given id.
    /// @param bribeId ID of the bribe.
    function updateBribePeriod(uint256 bribeId) external nonReentrant {
        _updateBribePeriod(bribeId);
    }

    /// @notice Update multiple bribes for given ids.
    /// @param ids Array of Bribe IDs.
    function updateBribePeriods(uint256[] calldata ids) external nonReentrant {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; ) {
            _updateBribePeriod(ids[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim all rewards for multiple bribes.
    /// @param ids Array of bribe IDs to claim.
    function claimAll(uint256[] calldata ids) external {
        address recipient = factory.recipient(
            msg.sender,
            address(gaugeController)
        );
        recipient = recipient != address(0) ? recipient : msg.sender;

        uint256 length = ids.length;

        for (uint256 i = 0; i < length; ) {
            uint256 id = ids[i];
            _claim(msg.sender, recipient, id);

            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a given bribe.
    /// @param user Address of the user.
    /// @param bribeId ID of the bribe.
    /// @return amount of rewards claimed.
    function _claim(
        address user,
        address recipient,
        uint256 bribeId
    ) internal nonReentrant notKilled returns (uint256 amount) {
        if (isBlacklisted[bribeId][user]) return 0;
        // Update if needed the current period.
        uint256 currentPeriod = _updateBribePeriod(bribeId);

        Bribe storage bribe = bribes[bribeId];

        // Get the last_vote timestamp.
        uint256 lastVote = gaugeController.last_user_vote(user, bribe.gauge);

        GaugeController.VotedSlope memory userSlope = gaugeController
            .vote_user_slopes(user, bribe.gauge);

        if (
            userSlope.slope == 0 ||
            lastUserClaim[user][bribeId] >= currentPeriod ||
            currentPeriod >= userSlope.end ||
            currentPeriod <= lastVote ||
            currentPeriod >= bribe.endTimestamp ||
            currentPeriod != getCurrentPeriod() ||
            amountClaimed[bribeId] == bribe.totalRewardAmount
        ) return 0;

        // Update User last claim period.
        lastUserClaim[user][bribeId] = currentPeriod;

        // Voting Power = userSlope * dt
        // with dt = lock_end - period.
        uint256 _bias = _getAddrBias(
            userSlope.slope,
            userSlope.end,
            currentPeriod
        );
        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = _bias.mulWadDown(rewardPerVote[bribeId]);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWadDown(bribe.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = _min(amount, _amountWithMaxPrice);

        // Update the amount claimed.
        uint256 _amountClaimed = amountClaimed[bribeId];

        if (amount + _amountClaimed > bribe.totalRewardAmount) {
            amount = bribe.totalRewardAmount - _amountClaimed;
        }

        amountClaimed[bribeId] += amount;

        uint256 feeAmount;
        address feeManager = factory.platformFeeManager(
            address(gaugeController)
        );
        uint256 platformFee = FeeManager(feeManager).totalFee();

        if (platformFee != 0) {
            feeAmount = amount.mulWadDown(platformFee);
            amount -= feeAmount;

            // Transfer fees.
            ERC20(bribe.rewardToken).safeTransfer(feeManager, feeAmount);
        }

        // Transfer to user.
        ERC20(bribe.rewardToken).safeTransfer(recipient, amount);

        emit Claimed(
            user,
            bribe.rewardToken,
            bribeId,
            amount,
            feeAmount,
            currentPeriod
        );
    }

    /// @notice Update the current period for a given bribe.
    /// @param bribeId Bribe ID.
    /// @return current/updated period.
    function _updateBribePeriod(uint256 bribeId) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[bribeId];

        uint256 currentPeriod = getCurrentPeriod();

        if (_activePeriod.id == 0 && currentPeriod == _activePeriod.timestamp) {
            // Checkpoint gauge to have up to date gauge weight.
            gaugeController.checkpoint_gauge(bribes[bribeId].gauge);
            // Initialize reward per token.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(bribeId, currentPeriod);
        }

        // Increase Period
        if (block.timestamp >= _activePeriod.timestamp + _WEEK) {
            // Checkpoint gauge to have up to date gauge weight.
            gaugeController.checkpoint_gauge(bribes[bribeId].gauge);
            // Roll to next period.
            _rollOverToNextPeriod(bribeId, currentPeriod);

            return currentPeriod;
        }

        return _activePeriod.timestamp;
    }

    /// @notice Roll over to next period.
    /// @param bribeId Bribe ID.
    /// @param currentPeriod Next period timestamp.
    function _rollOverToNextPeriod(uint256 bribeId, uint256 currentPeriod)
        internal
    {
        uint8 index = getActivePeriodPerBribe(bribeId);

        Upgrade storage upgradedBribe = upgradeBribeQueue[bribeId];

        // Check if there is an upgrade in queue.
        if (upgradedBribe.totalRewardAmount != 0) {
            // Save new values.
            bribes[bribeId].numberOfPeriods = upgradedBribe.numberOfPeriods;
            bribes[bribeId].totalRewardAmount = upgradedBribe.totalRewardAmount;
            bribes[bribeId].maxRewardPerVote = upgradedBribe.maxRewardPerVote;
            bribes[bribeId].endTimestamp = upgradedBribe.endTimestamp;

            if (upgradedBribe.blacklist.length > 0) {
                bribes[bribeId].blacklist = upgradedBribe.blacklist;
            }

            emit BribeDurationIncreased(
                bribeId,
                upgradedBribe.numberOfPeriods,
                upgradedBribe.totalRewardAmount,
                upgradedBribe.maxRewardPerVote
            );

            // Reset the next values.
            delete upgradeBribeQueue[bribeId];
        }

        Bribe storage bribe = bribes[bribeId];

        uint256 periodsLeft = getPeriodsLeft(bribeId);
        uint256 rewardPerPeriod;
        rewardPerPeriod = bribe.totalRewardAmount - amountClaimed[bribeId];

        if (bribe.endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDivDown(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 gaugeBias = _getAdjustedBias(
            bribe.gauge,
            bribe.blacklist,
            currentPeriod
        );

        rewardPerVote[bribeId] = rewardPerPeriod.mulDivDown(
            _BASE_UNIT,
            gaugeBias
        );
        activePeriod[bribeId] = Period(index, currentPeriod, rewardPerPeriod);

        emit PeriodRolledOver(bribeId, index, currentPeriod, rewardPerPeriod);
    }

    /// @notice Update the amount of reward per token for a given bribe.
    /// @dev This function is only called once per Bribe.
    function _updateRewardPerToken(uint256 bribeId, uint256 currentPeriod)
        internal
    {
        if (rewardPerVote[bribeId] == 0) {
            uint256 gaugeBias = _getAdjustedBias(
                bribes[bribeId].gauge,
                bribes[bribeId].blacklist,
                currentPeriod
            );
            if (gaugeBias != 0) {
                rewardPerVote[bribeId] = activePeriod[bribeId]
                    .rewardPerPeriod
                    .mulDivDown(_BASE_UNIT, gaugeBias);
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// ---  VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get an estimate of the reward amount for a given user.
    /// @param user Address of the user.
    /// @param bribeId ID of the bribe.
    /// @return amount of rewards.
    /// Mainly used for UI.
    function claimable(address user, uint256 bribeId)
        external
        view
        returns (uint256 amount)
    {
        if (isBlacklisted[bribeId][user]) return 0;

        Bribe memory bribe = bribes[bribeId];
        // If there is an upgrade in progress but period hasn't been rolled over yet.
        Upgrade storage upgradedBribe = upgradeBribeQueue[bribeId];

        // Update if needed the current period.
        uint256 currentPeriod = getCurrentPeriod();
        // End timestamp of the bribe.
        uint256 endTimestamp = _max(
            bribe.endTimestamp,
            upgradedBribe.endTimestamp
        );
        // Get the last_vote timestamp.
        uint256 lastVote = gaugeController.last_user_vote(user, bribe.gauge);

        GaugeController.VotedSlope memory userSlope = gaugeController
            .vote_user_slopes(user, bribe.gauge);

        if (
            userSlope.slope == 0 ||
            lastUserClaim[user][bribeId] >= currentPeriod ||
            currentPeriod >= userSlope.end ||
            currentPeriod <= lastVote ||
            currentPeriod >= endTimestamp ||
            currentPeriod < getActivePeriod(bribeId).timestamp ||
            amountClaimed[bribeId] >= bribe.totalRewardAmount
        ) return 0;

        uint256 _rewardPerVote = rewardPerVote[bribeId];
        // If period updated.
        if (
            _rewardPerVote == 0 ||
            (_rewardPerVote > 0 &&
                getActivePeriod(bribeId).timestamp != currentPeriod)
        ) {
            uint256 _rewardPerPeriod;

            if (upgradedBribe.numberOfPeriods != 0) {
                // Update max reward per vote.
                bribe.maxRewardPerVote = upgradedBribe.maxRewardPerVote;
                bribe.totalRewardAmount = upgradedBribe.totalRewardAmount;
            }

            uint256 periodsLeft = endTimestamp > currentPeriod
                ? (endTimestamp - currentPeriod) / _WEEK
                : 0;
            _rewardPerPeriod = bribe.totalRewardAmount - amountClaimed[bribeId];

            if (endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
                _rewardPerPeriod = _rewardPerPeriod.mulDivDown(1, periodsLeft);
            }

            // Get Adjusted Slope without blacklisted addresses weight.
            uint256 gaugeBias = _getAdjustedBias(
                bribe.gauge,
                bribe.blacklist,
                currentPeriod
            );
            _rewardPerVote = _rewardPerPeriod.mulDivDown(_BASE_UNIT, gaugeBias);
        }
        // Get user voting power.
        uint256 _bias = _getAddrBias(
            userSlope.slope,
            userSlope.end,
            currentPeriod
        );
        // Estimation of the amount of rewards.
        amount = _bias.mulWadDown(_rewardPerVote);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWadDown(bribe.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = _min(amount, _amountWithMaxPrice);

        uint256 _amountClaimed = amountClaimed[bribeId];
        // Update the amount claimed.
        if (amount + _amountClaimed > bribe.totalRewardAmount) {
            amount = bribe.totalRewardAmount - _amountClaimed;
        }
        // Substract fees.
        uint256 platformFee = FeeManager(
            factory.platformFeeManager(address(gaugeController))
        ).totalFee();
        if (platformFee != 0) {
            amount = amount.mulWadDown(_BASE_UNIT - platformFee);
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get adjusted slope from Gauge Controller for a given gauge address.
    /// Remove the weight of blacklisted addresses.
    /// @param gauge Address of the gauge.
    /// @param _addressesBlacklisted Array of blacklisted addresses.
    /// @param period   Timestamp to check vote weight.
    function _getAdjustedBias(
        address gauge,
        address[] memory _addressesBlacklisted,
        uint256 period
    ) internal view returns (uint256 gaugeBias) {
        // Cache the user slope.
        GaugeController.VotedSlope memory userSlope;
        // Bias
        uint256 _bias;
        // Last Vote
        uint256 _lastVote;
        // Cache the length of the array.
        uint256 length = _addressesBlacklisted.length;
        // Cache blacklist.
        // Get the gauge slope.
        gaugeBias = gaugeController.points_weight(gauge, period).bias;

        for (uint256 i = 0; i < length; ) {
            // Get the user slope.
            userSlope = gaugeController.vote_user_slopes(
                _addressesBlacklisted[i],
                gauge
            );
            _lastVote = gaugeController.last_user_vote(
                _addressesBlacklisted[i],
                gauge
            );
            if (period > _lastVote) {
                _bias = _getAddrBias(userSlope.slope, userSlope.end, period);
                gaugeBias -= _bias;
            }
            // Increment i.
            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Increase Bribe duration.
    /// @param _bribeId ID of the bribe.
    /// @param _additionnalPeriods Number of periods to add.
    /// @param _increasedAmount Total reward amount to add.
    /// @param _newMaxPricePerVote Total reward amount to add.
    function increaseBribeDuration(
        uint256 _bribeId,
        uint8 _additionnalPeriods,
        uint256 _increasedAmount,
        uint256 _newMaxPricePerVote,
        address[] calldata _addressesBlacklisted
    ) external nonReentrant notKilled onlyManager(_bribeId) {
        if (!isUpgradeable[_bribeId]) revert NOT_UPGRADEABLE();
        if (getPeriodsLeft(_bribeId) < 1) revert NO_PERIODS_LEFT();
        if (_increasedAmount == 0 || _newMaxPricePerVote == 0)
            revert WRONG_INPUT();

        Bribe storage bribe = bribes[_bribeId];
        Upgrade memory upgradedBribe = upgradeBribeQueue[_bribeId];

        ERC20(bribe.rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            _increasedAmount
        );

        if (upgradedBribe.totalRewardAmount != 0) {
            upgradedBribe = Upgrade({
                numberOfPeriods: upgradedBribe.numberOfPeriods +
                    _additionnalPeriods,
                totalRewardAmount: upgradedBribe.totalRewardAmount +
                    _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: upgradedBribe.endTimestamp +
                    (_additionnalPeriods * _WEEK),
                blacklist: _addressesBlacklisted
            });
        } else {
            upgradedBribe = Upgrade({
                numberOfPeriods: bribe.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: bribe.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: bribe.endTimestamp +
                    (_additionnalPeriods * _WEEK),
                blacklist: _addressesBlacklisted
            });
        }

        upgradeBribeQueue[_bribeId] = upgradedBribe;

        emit BribeDurationIncreaseQueued(
            _bribeId,
            upgradedBribe.numberOfPeriods,
            upgradedBribe.totalRewardAmount,
            _newMaxPricePerVote
        );
    }

    /// @notice Close Bribe if there is remaining.
    /// @param bribeId ID of the bribe to close.
    function closeBribe(uint256 bribeId)
        external
        nonReentrant
        onlyManager(bribeId)
    {
        // Check if the currentPeriod is the last one.
        // If not, we can increase the duration.
        Bribe storage bribe = bribes[bribeId];

        if (getCurrentPeriod() >= bribe.endTimestamp || isKilled) {
            uint256 leftOver;
            Upgrade memory upgradedBribe = upgradeBribeQueue[bribeId];
            if (upgradedBribe.totalRewardAmount != 0) {
                leftOver =
                    upgradedBribe.totalRewardAmount -
                    amountClaimed[bribeId];
                delete upgradeBribeQueue[bribeId];
            } else {
                leftOver =
                    bribes[bribeId].totalRewardAmount -
                    amountClaimed[bribeId];
            }
            // Transfer the left over to the owner.
            ERC20(bribe.rewardToken).safeTransfer(bribe.manager, leftOver);
            delete bribes[bribeId].manager;

            emit BribeClosed(bribeId, leftOver);
        }
    }

    /// @notice Update Bribe Manager.
    /// @param bribeId ID of the bribe.
    /// @param newManager Address of the new manager.
    function updateManager(uint256 bribeId, address newManager)
        external
        nonReentrant
        onlyManager(bribeId)
    {
        emit ManagerUpdated(bribeId, bribes[bribeId].manager = newManager);
    }

    function kill() external {
        if (msg.sender != address(factory)) revert NOT_ALLOWED_OPERATION();
        isKilled = true;
    }

    ////////////////////////////////////////////////////////////////
    /// --- UTILS FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Returns the number of periods left for a given bribe.
    /// @param bribeId ID of the bribe.
    function getPeriodsLeft(uint256 bribeId)
        public
        view
        returns (uint256 periodsLeft)
    {
        Bribe storage bribe = bribes[bribeId];

        uint256 currentPeriod = getCurrentPeriod();
        periodsLeft = bribe.endTimestamp > currentPeriod
            ? (bribe.endTimestamp - currentPeriod) / _WEEK
            : 0;
    }

    /// @notice Return the bribe object for a given ID.
    /// @param bribeId ID of the bribe.
    function getBribe(uint256 bribeId) external view returns (Bribe memory) {
        return bribes[bribeId];
    }

    /// @notice Return the bribe in queue for a given ID.
    /// @dev Can return an empty bribe if there is no upgrade.
    /// @param bribeId ID of the bribe.
    function getUpgradedBribeQueued(uint256 bribeId)
        external
        view
        returns (Upgrade memory)
    {
        return upgradeBribeQueue[bribeId];
    }

    /// @notice Return the blacklisted addresses of a bribe for a given ID.
    /// @param bribeId ID of the bribe.
    function getBlacklistedAddressesForBribe(uint256 bribeId)
        external
        view
        returns (address[] memory)
    {
        return bribes[bribeId].blacklist;
    }

    /// @notice Return the active period running of bribe given an ID.
    /// @param bribeId ID of the bribe.
    function getActivePeriod(uint256 bribeId)
        public
        view
        returns (Period memory)
    {
        return activePeriod[bribeId];
    }

    /// @notice Return the expected current period id.
    /// @param bribeId ID of the bribe.
    function getActivePeriodPerBribe(uint256 bribeId)
        public
        view
        returns (uint8)
    {
        Bribe storage bribe = bribes[bribeId];

        uint256 currentPeriod = getCurrentPeriod();
        uint256 periodsLeft = bribe.endTimestamp > currentPeriod
            ? (bribe.endTimestamp - currentPeriod) / _WEEK
            : 0;
        // If periodsLeft is superior, then the bribe didn't start yet.
        return
            uint8(
                periodsLeft > bribe.numberOfPeriods
                    ? 0
                    : bribe.numberOfPeriods - periodsLeft
            );
    }

    /// @notice Return the current period based on Gauge Controller rounding.
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / _WEEK) * _WEEK;
    }

    /// @notice Return the minimum between two numbers.
    /// @param a First number.
    /// @param b Second number.
    function _min(uint256 a, uint256 b) private pure returns (uint256 min) {
        min = a < b ? a : b;
    }

    /// @notice Return the maximum between two numbers.
    /// @param a First number.
    /// @param b Second number.
    function _max(uint256 a, uint256 b) private pure returns (uint256 max) {
        max = a < b ? b : a;
    }

    /// @notice Return the bias of a given address based on its lock end date and the current period.
    /// @param userSlope User slope.
    /// @param endLockTime Lock end date of the address.
    /// @param currentPeriod Current period.
    function _getAddrBias(
        uint256 userSlope,
        uint256 endLockTime,
        uint256 currentPeriod
    ) internal pure returns (uint256) {
        if (currentPeriod + _WEEK >= endLockTime) return 0;
        return userSlope * (endLockTime - currentPeriod);
    }
}

/// @notice Library for converting between addresses and bytes32 values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/Bytes32AddressLib.sol)
library Bytes32AddressLib {
    function fromLast20Bytes(bytes32 bytesValue) internal pure returns (address) {
        return address(uint160(uint256(bytesValue)));
    }

    function fillLast12Bytes(address addressValue) internal pure returns (bytes32) {
        return bytes32(bytes20(addressValue));
    }
}

contract PlatformFactory is Owned, Factory {
    using Bytes32AddressLib for address;
    using Bytes32AddressLib for bytes32;

    /// @notice Fee recipient.
    address public feeCollector;

    /// @notice Fee Manager per gaugeController.
    mapping(address => address) public feeManagerPerGaugeController;

    /// @notice Recipient per address per gaugeController.
    mapping(address => mapping(address => address)) public recipient;

    /// @notice Emitted when a new platform is deployed.
    event PlatformDeployed(
        Platform indexed platform,
        address indexed gaugeController,
        FeeManager indexed feeManager
    );

    /// @notice Emitted when a platform is killed.
    event PlatformKilled(
        Platform indexed platform,
        address indexed gaugeController
    );

    /// @notice Emitted when a recipient is set for an address.
    event RecipientSet(address indexed sender, address indexed recipient);

    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Creates a Platform factory.
    /// @param _owner The owner of the factory.
    constructor(address _owner, address _feeCollector) Owned(_owner) {
        feeCollector = _feeCollector;
    }

    function deploy(address _gaugeController)
        external
        returns (Platform platform)
    {
        // Deploy the platform.
        platform = new Platform{
            salt: address(_gaugeController).fillLast12Bytes()
        }(_gaugeController, address(this));
        FeeManager feeManager = new FeeManager{
            salt: address(_gaugeController).fillLast12Bytes()
        }(feeCollector);
        feeManagerPerGaugeController[_gaugeController] = address(feeManager);

        emit PlatformDeployed(platform, _gaugeController, feeManager);
    }

    /// @notice Computes a Platform address from its gauge controller.
    function getPlatformFromGaugeController(address gaugeController)
        external
        view
        returns (Platform)
    {
        return
            Platform(
                payable(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xFF),
                            address(this),
                            address(gaugeController).fillLast12Bytes(),
                            keccak256(
                                abi.encodePacked(
                                    type(Platform).creationCode,
                                    abi.encode(gaugeController, address(this))
                                )
                            )
                        )
                    ).fromLast20Bytes() // Convert the CREATE2 hash into an address.
                )
            );
    }

    function setRecipient(address _recipient, address _gaugeController)
        external
    {
        recipient[msg.sender][_gaugeController] = _recipient;

        emit RecipientSet(msg.sender, _recipient);
    }

    function setRecipientFor(
        address _recipient,
        address _gaugeController,
        address _for
    ) external onlyOwner {
        recipient[_for][_gaugeController] = _recipient;

        emit RecipientSet(_for, _recipient);
    }

    function setFeeManager(address _gaugeController, address _feeManager)
        external
        onlyOwner
    {
        feeManagerPerGaugeController[_gaugeController] = _feeManager;
    }

    function platformFeeManager(address _gaugeController)
        external
        view
        returns (address)
    {
        return feeManagerPerGaugeController[_gaugeController];
    }

    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;
    }

    function kill(address platform) external onlyOwner {
        Platform(platform).kill();
        emit PlatformKilled(
            Platform(platform),
            address(Platform(platform).gaugeController())
        );
    }
}
