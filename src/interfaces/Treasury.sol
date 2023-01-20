// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev The Treasury will hold all assets.
 */
interface ITreasury {
    /// @dev When native network token is withdrawn from the Treasury
    event Deposit(uint amount);

    /// @dev When an ERC20 is depositted into the vault
    event DepositERC20(address token, uint amount);

    /// @dev When an ERC721 is depositted into the vault
    event DepositERC721(address token, uint tokenId);

    /// @dev When an ERC1155 is depositted into the vault
    event DepositERC1155(address token, uint tokenId, uint amount);

    /// @dev When native network token is withdrawn from the Treasury
    event Withdraw(uint amount, address recipient);

    /// @dev When an ERC20 token is withdrawn from the Treasury
    event WithdrawERC20(address token, uint amount, address recipient);

    /// @dev When an ERC721 token is withdrawn from the Treasury
    event WithdrawERC721(address token, uint tokenId, address recipient);

    /// @dev When an ERC1155 is withdrawn from the vault
    event WithdrawERC1155(address token, uint tokenId, uint amount, address recipient);

    /// @dev When multiplier pool has been updated
    event MultiplierPoolUpdated(uint percent);

    /// @dev When FLOOR is minted
    event FloorMinted(uint amount);

    /// @dev When an epoch has ended
    event EpochEnded(uint timestamp, uint totalRewards);

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
     * Allow FLOOR token to be minted. This should be called from the deposit method
     * internally, but a public method will allow a {TreasuryManager} to bypass this
     * and create additional FLOOR tokens if needed.
     *
     * @dev We only want to do this on creation and for inflation. Have a think on how
     * we can implement this!
     */
    function mint(uint amount) external;

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
     * Allows an ERC1155 token(s) to be deposited and generates FLOOR tokens based on
     * the current determined value of FLOOR and the token.
     */
    function depositERC1155(address token, uint tokenId, uint amount) external;

    /**
     * Allows an approved user to withdraw native token.
     */
    function withdraw(address recipient, uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC20 token from the vault.
     */
    function withdrawERC20(address recipient, address token, uint amount) external;

    /**
     * Allows an approved user to withdraw and ERC721 token from the vault.
     */
    function withdrawERC721(address recipient, address token, uint tokenId) external;

    /**
     * Allows an approved user to withdraw an ERC1155 token(s) from the vault.
     */
    function withdrawERC1155(address recipient, address token, uint tokenId, uint amount) external;

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
     * Allows the FLOOR minting to be enabled or disabled. If this is disabled, then reward
     * tokens will be distributed directly, otherwise they will be converted to FLOOR token
     * first and then distributed.
     *
     * @dev This will only be actionable by {TreasuryManager}
     */
    function pauseFloorMinting(bool enabled) external;

    /**
     * Sets an updated pricing executor (needs to confirm an implementation function).
     */
    function setPricingExecutor(address contractAddr) external;
}
