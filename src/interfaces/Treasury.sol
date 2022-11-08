// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * @dev The Treasury will hold all assets.
 */
interface ITreasury {

    /// @dev When native network token is withdrawn from the Treasury
    event Deposit(uint amount);

    /// @dev When an ERC20 is depositted into the vault
    event DepositERC20(uint amount, address token);

    /// @dev When an ERC721 is depositted into the vault
    event DepositERC721(address token, uint tokenId);

    /// @dev When native network token is withdrawn from the Treasury
    event Withdraw(uint amount);

    /// @dev When an ERC20 token is withdrawn from the Treasury
    event WithdrawERC20(address token, uint amount);

    /// @dev When an ERC721 token is withdrawn from the Treasury
    event WithdrawERC721(address token, uint tokenId);

    /// @dev When multiplier pool has been updated
    event MultiplierPoolUpdated(uint percent);

    /// @dev When FLOOR is minted
    event FloorMinted(uint amount);


    /**
     * Distributes reward tokens to the {RewardsLedger}, sending either the FLOOR token
     * or the base reward token depending on {toggleFloorMinting}. This function will
     * need to iterate over the pending deposits and:
     *  - If the reward is from treasury yield, then the recipient is based on GWV.
     *  - If the reward is from staker yield, then it will be allocated to user in {RewardsLedger}.
     *
     * The user that will be allocated to is the holder of the fToken. This token is essentially
     * the receipt of the deposit into a vault. As such, this fToken can be transferred freely but
     * will grant the holder access to the position, and also the rewards from the position. This
     * will be handled by transfer hooks in the token and will update vault data accordingly.
     *
     * When a token deposit from strategy reward yield comes in, we can find the matching vault and
     * find the holdings of all users. The treasury user is a special case, but the others will have
     * a holding percentage determined for their reward share. Only users that are eligible (see note
     * below on rewards cycle) will have their holdings percentage calculated. This holdings
     * percentage will get them FLOOR rewards of all non-treasury yield, plus non-retained treasury
     * yield based on {setRetainedTreasuryYieldPercentage}. So in this example:
     *
     * +----------------+-----------------+-------------------+
     * | Staker         | Amount          | Percent           |
     * +----------------+-----------------+-------------------+
     * | Alice          | 30              | 30%               |
     * | Bob            | 10              | 10%               |
     * | Treasury       | 60              | 60%               |
     * +----------------+-----------------+-------------------+
     *
     * The strategy collects 10 tokens in reward in this cycle, and all staked parties are eligible
     * to receive their reward allocation. The Treasury does not mint FLOOR against their reward token,
     * but instead just holds it inside of the Treasury.
     *
     * The GWV in this example is attributing 40% to the example vault and we assume a FLOOR to token
     * ratio of 5:1 (5 FLOOR is minted for each reward token in treasury). We are also assumging that
     * we are retaining 50% of treasury rewards, that floor minting is enabled and that we don't have
     * a premium FLOOR mint amount being applied.
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
     * A user will only be eligible if they have been staked for a complete
     * rewards epoch. This needs to be validated to ensure that the epoch timelock
     * has been surpassed.
     */
    function endEpoch() external;

    /**
     * Allows the treasury to extract the generated reward tokens from a number of
     * strategies and move them to the {Treasury}. This uses the {Strategy} `rewardToken`
     * to determine which token(s) should be transferred.
     */
    function extractFromStrategies(address[] calldata strategies) external;

    /**
     * Allow FLOOR token to be minted. This should be called from the deposit method
     * internally, but a public method will allow a {TreasuryManager} to bypass this
     * and create additional FLOOR tokens if needed.
     *
     * @dev We only want to do this on creation and for inflation. Have a think on how
     * we can implement this!
     */
    function mint(uint amount) external;

    /**
     * Allows us to mint floor based on the recorded token > Floor ratio. This will
     * mean that we don't have to transact the token before running our calculations.
     *
     * @dev If the pricing is deemed stale, we will need to ensure that the pricing
     * ratio is updated before minting.
     */
    function mintTokenFloor(address token, uint amount) external;

    /**
     * Allows an ERC20 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     */
    function depositERC20(address token, uint amount) external;

    /**
     * Allows an ERC721 token to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     */
    function depositERC721(address token, uint tokenId) external;

    /**
     * Allows an approved user to withdraw native token.
     */
    function withdraw(uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC20 token from the vault.
     */
    function withdrawERC20(address token, uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC721 token from the vault.
     */
    function withdrawERC721(address token, uint tokenId) external;

    /**
     * Allows the RewardsLedger contract address to be set.
     *
     * @dev Should we allow this to be updated or should be immutable?
     */
    function setRewardsLedgerContract(address contractAddr) external;

    /**
     * Allows the GWV contract address to be set.
     *
     * @dev Should we allow this to be updated or should be immutable?
     */
    function setGaugeWeightVoteContract(address contractAddr) external;

    /**
     * Sets the percentage of treasury rewards yield to be retained by the treasury, with
     * the remaining percetange distributed to non-treasury vault stakers based on the GWV.
     */
    function setRetainedTreasuryYieldPercentage(uint percent) external;

    /**
     * With simple inflation you have people voting for pools that are not necessarily good
     * for yield. With a yield multiplier people will only benefit if they vote for vaults
     * that are productive. Users could vote to distribute from a multiplier pool, say 200%,
     * boost and split that multiplier across vaults in the GWV.
     *
     * The DAO can adjust the size of the multiplier pool.
     *
     * So if all users voted for the PUNK vault it'd have a 200% multiplier. This would act
     * as ongoing inflation (tied to yield), which the DAO can adjust to target some overall
     * inflation amount. Then treasury yield can be left in treasury and not redirected to
     * vaults. The DAO can use that yield to do giveaways/promotions.
     *
     * So the treasury can have logic that allows us to set a multiplier pool and then a GWV
     * mechanic can decide the distribution
     */
    function setPoolMultiplierPercentage(uint percent) external;

    /**
     * Allows the FLOOR minting to be enabled or disabled. If this is disabled, then reward
     * tokens will be distributed directly, otherwise they will be converted to FLOOR token
     * first and then distributed.
     *
     * @dev This will only be actionable by {TreasuryManager}
     */
    function pauseFloorMinting(bool enabled) external;

    /**
     * Updates our FLOOR <-> token price mapping to determine the amount of FLOOR to allocate
     * as user rewards. Updated prices will be stored against a rudimentary caching system that
     * will only source a new token price mapping against FLOOR if it has surpassed a set time
     * window (e.g. 30 minutes).
     *
     * The vault will handle its own internal price calculation and stale caching logic based
     * on a {VaultPricingStrategy} tied to the vault.
     *
     * @dev Our FLOOR ETH price is determined by:
     * https://app.uniswap.org/#/swap?outputCurrency=0xf59257E961883636290411c11ec5Ae622d19455e&inputCurrency=ETH&chain=Mainnet
     *
     * Our token ETH price is determined by (e.g. PUNK):
     * https://app.uniswap.org/#/swap?outputCurrency=0xf59257E961883636290411c11ec5Ae622d19455e&inputCurrency=ETH&chain=Mainnet
     *
     * Questions:
     * - Can we just compare FLOOR <-> TOKEN on Uniswap? Rather than each to ETH? It wouldn't need
     *   to affect the price as this is just a x:y without actioning. Check Twade notes, higher value
     *   in direct comparison due to hops.
     */
    function getTokenFloorPrice(address token) external;

    /**
     * Returns the current pricing executor and reverts if none is set.
     */
    function getPricingExecutor() external returns (address);

    /**
     * Sets an updated pricing executor (needs to confirm an implementation function).
     */
    function setPricingExecutor(address contractAddr) external;

    /**
     * Deploys an instance of an approved strategy, allowing tokens and relative amounts to be
     * provided that will fund the strategy.
     *
     * Treasury strategies are used to act as non-public DeFi pools that will (hopefully) increase
     * vault value. FLOOR tokens will still be minted based on the retained treasury yield
     * percentage, etc. just as a normal vault strategy would. The only difference is that only
     * the {Treasury} will be able to participate.
     *
     * The returned address is the instance of the new strategy deployment.
     */
    function deployAndFundTreasuryStrategy(address strategyAddr, address[] calldata token, uint[] calldata amount) external returns (address);

}
