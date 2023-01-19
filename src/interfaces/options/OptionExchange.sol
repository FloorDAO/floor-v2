// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * The {OptionExchange} will allow FLOOR to be burnt to redeem treasury assets.
 * This is important to allow us to balance token value against treasury backed
 * assets that are accumulated.
 *
 * Our {OptionExchange} will allow a {TreasuryManager} to transfer an ERC20 from
 * the {Treasury} and create an `OptionPool` with a defined available amount,
 * maximum discount and expiry timestamp.
 *
 * With a pool, we can then hit an API via ChainLink to generate a range of random
 * `OptionAllocation`s that will provide the lucky recipient with access to burn
 * their FLOOR tokens for allocated treasury assets at a discount. This discount
 * will be randomly assigned and user's will receive a maximum of one option per
 * pool allocation.
 *
 * We hit an external API as Solidity randomness is not random.
 *
 * Further information about this generation is outlined in the `generateAllocations`
 * function documentation.
 */
interface IOptionExchange {
    /**
     * Each active pool will have a corresponding `OptionPool` structure. This
     * will define the token and amount made available for options, as well as
     * some configuration variables that will be used in the generation of the
     * `OptionAllocation`s.
     *
     * If we made a subsequent deposit into the exchange with the same token as
     * an existing pool, then these will be treated as separate pools and not
     * merged into one.
     *
     * @param token The address of the ERC20 token that has been made available
     * @param amount The 18-decimal representation of the token amount that is
     * left available in the pool. This should be decremented whenever a withdrawal
     * is made from the pool
     * @param initialAmount The 18-decimal amount of the token that was initially
     * made available to the pool
     * @param maxDiscount This is the maximum discount that can be applied during
     * allocation generation
     * @param expires The unix timestamp at which the option allocations will no
     * longer be redeemable against the pool
     */
    struct OptionPool {
        uint amount;
        uint initialAmount;
        address token;
        uint16 maxDiscount;
        uint64 expires;
        bool initialised;
        uint requestId;
    }

    /**
     * ...
     */
    struct RequestStatus {
        uint paid; // amount paid in link
        bool fulfilled;
        uint[] randomWords;
        uint poolId;
    }

    /**
     * Each `OptionPool` will have a 1:n releationship with `OptionAllocation`s, with
     * each user that is granted an allocation having an assigned `OptionAllocation`.
     *
     * The `OptionAllocation` will be used as a precusor to the ERC721 {Option} token
     * being minted, essentially providing the relevant information at time of mint. Once
     * minted, the ERC721 will hold and maintain the data.
     *
     * @param recipient The address that has been granted the {Option}
     * @param pool The numerical index of the `OptionPool`
     * @param amount The 18-decimal token amount available to the user. Although it will
     * be calculated as a percentage during generation, this value will be the direct
     * token amount available to the user
     * @param discount A percentage value highlighting the FLOOR discount that will be
     * factored into the claiming calculation
     */
    struct OptionAllocation {
        address recipient;
        uint poolId;
        uint amount;
        uint discount;
    }

    /// @dev Emitted when an `OptionAllocation` is created
    event AllocationCreated(address recipient, uint poolId, uint amount, uint discount);

    /// @dev Emitted when a user has minted their allocated {Option}
    event AllocationMinted(uint tokenId);

    /// @dev Emitted when a new `OptionPool` is created
    event OptionPoolCreated(uint poolId);

    /// @dev Emitted when an `OptionPool` has been depleted through either through all
    /// options being actioned or after it has expired and it has been withdrawn. This
    /// will not be emitted purely at point of expiry.
    event OptionPoolClosed(uint poolId);

    /// @dev Emitted when our $LINK balance drops below a set threshold
    event LinkBalanceLow(uint remainingBalance);

    /// @dev Emitted when our $LINK balance has been updated. These senders should be
    /// praised like the true giga chads that they are.
    event LinkBalanceIncreased(address sender, uint amount);

    /// @dev Emitted when we have received a response from Chainlink with our generated
    /// allocations
    event RequestFulfilled(uint requestId, bytes32 merkleRoot);

    /// @dev Emitted when our exchange FLOOR recipient address is updated
    event UpdatedFloorRecipient(address newRecipient);

    /// @dev Emitted when our distribution calculator is updated
    event DistributionCalculatorUpdated(address newCalculator);

    /**
     * Provides the `OptionPool` struct data. If the index cannot be found, then we
     * will receive an empty response.
     */
    function getOptionPool(uint poolId) external returns (OptionPool memory);

    /**
     * Starts the process of our allocation generation; sending a request to a specified
     * ChainLink node and returning the information required to generate a range of
     * {OptionAllocation} structs.
     *
     * This generation will need to function via a hosted API that will determine the
     * share and discount attributes for an option. From these two attributes we will
     * also define a rarity ranking based on the liklihood of the result.
     *
     * The algorithm for the attributions can be updated as needed, but in it's current
     * iteration they are both derived from a right sided bell curve. This ensures no
     * negative values, but provides the majority of the distribution to be allocated
     * across smaller numbers.
     *
     * https://www.investopedia.com/terms/b/bell-curve.asp
     *
     * The allocation of the amount should not allow for a zero value, but the discount
     * can be.
     *
     * Chainlink will return a bytes32 request ID that we can track internally over the
     * process so that when it is subsequently fulfilled we can map our allocations to
     * the correct `OptionPool`.
     *
     * When this call is made, if we have a low balance of $LINK token in our contract
     * then we will need to fire an {LinkBalanceLow} event to pick this up.
     */
    function generateAllocations(uint poolId) external returns (uint requestId);

    /**
     * Allows our {TreasuryManager} to create an `OptionPool` from tokens that have been
     * passed in from the `deposit` function. Although we need to ensure that we have
     * sufficient token amounts in the contract, we additionally need to ensure that
     * they are not currently being used in existing `OptionPool` structures.
     *
     * This would mean that user's would not be able to action their {Option}, which is
     * a bad thing.
     *
     * Should emit the {OptionPoolCreated} event.
     */
    function createPool(address token, uint amount, uint16 maxDiscount, uint64 expires) external returns (uint);

    /**
     * Allows the specified recipient to mint their `OptionAllocation`. This will
     * need to ensure that the relevant `OptionalPool` has not expired and the expected
     * sense checks, such as that it exists, has not already been allocated, etc.
     *
     * As a recipient address can only be programatically allocated a singular option
     * per-pool during the generation process, we can determine the option by just
     * providing the `poolId` and then checking that the `msg.sender` matches the
     * `OptionAllocation`.`recipient`
     *
     * Once this has been minted we should delete the appropriate `OptionAllocation`
     * as this will prevent subsequent minting and also gives some gas refunds.
     *
     * Once minted, an ERC721 will be transferred to the recipient that will be used
     * to allow the holder to partially or fully action the option.
     */
    function mintOptionAllocation(bytes32 dna, uint index, bytes32[] calldata merkleProof) external;

    /**
     * We should be able to action a holders {Option} to allow them to exchange their
     * FLOOR token for another token. This will take the allocation amount in their
     * {Option} token, as well as factoring in their discount, to determine the amount
     * of token they will receive in exchange.
     *
     * As the user's allocation is based on the target token, rather than FLOOR, we want
     * to ensure that the user is left with as little dust as possible. This means the
     * amount of FLOOR (`tokenIn`) required may change during the transaction lifetime,
     * but the amount of `tokenOut` should always remain the same.
     *
     * It's for this reason that we have an `approvedMovement` attribute. Similar to how
     * slippage would be handled, we allow the user to specify a range of FLOOR input
     * variance that they are willing to accept. The frontend UX will need to correlate
     * this against the user's balance as, for example, they may enter their full balance
     * and specify 1% movement, but they could not acommodate this.
     *
     * The sender will need to have approved this contract to manage their FLOOR token
     * as we will transfer the required equivalent value of the token.
     *
     * There will be a number of validation steps to our action flow here:
     *  - Does the sender has permission to action the {Option}?
     *  - Does the sender hold sufficient FLOOR?
     *  - Does the {Option} have sufficient allocation for the floorIn requested?
     *  - Does the floorIn / tokenOut make sense at current price within approvedMovement?
     *
     * The final FLOOR requirement should follow this pseudo algorithm:
     *
     *  floor pre-discount  = tokens out * (token value / floor value)
     *  floor required (fr) = f - ((f * discount) / 100)
     *
     * We can then assert floor required against our approved movement:
     *
     *  (floorIn - (approvedMovement * (floorIn / 100))) < fr < (floorIn + (approvedMovement * (floorIn / 100)))
     *
     * FLOOR received from this transaction will be sent to an address. Upon contract
     * creation this will be sent to a 0x0 NULL address to burn the token, but can be
     * updated via the `setFloorRecipient` function.
     *
     * If there is no remaining amount in the `OptionPool`, then the `OptionPool` will
     * not be deleted for historical purposes, but would emit the {OptionPoolClosed} event.
     */
    function action(uint tokenId, uint floorIn, uint tokenOut, uint approvedMovement) external;

    /**
     * The amount of FLOOR required to mint the specified `amount` of the `token`.
     *
     * This will call our {Treasury} to get the required price via the {PriceExecutor}.
     */
    function getRequiredFloorPrice(address token, uint amount) external returns (uint);

    /**
     * Provides a list of all allocations that the user has available to be minted.
     *
     * @param recipient Address of the claimant
     */
    function claimableOptionAllocations(address recipient) external view;

    /**
     * After an `OptionPool` has expired, any remaining token amounts can be transferred
     * back to the {Treasury} using this function. We must first ensure that it has expired
     * before performing this transaction.
     *
     * This will emit this {OptionPoolClosed} event.
     *
     * If there is substantial assets remaining, we could bypass our `withdraw` call and
     * instead just call `createPool` again with the same token referenced.
     */
    function withdraw(uint poolId) external;

    /**
     * Allows any sender to provide ChainLink token balance to the contract. This is
     * required for the generation of our user allocations.
     *
     * This should emit the {LinkBalanceIncreased} event.
     */
    function depositLink(uint amount) external;

    /**
     * By default, FLOOR received from an {Option} being actioned will be burnt by
     * sending it to a NULL address. If decisions change in the future then we want
     * to be able to update the recipient address.
     *
     * Should emit {UpdatedFloorRecipient} event.
     *
     * @param newRecipient The new address that will receive exchanged FLOOR tokens
     */
    function setFloorRecipient(address newRecipient) external;
}
