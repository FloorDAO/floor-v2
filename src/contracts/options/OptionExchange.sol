// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import '../../interfaces/options/OptionExchange.sol';


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
contract OptionExchange is ChainlinkClient, ConfirmedOwner, IOptionExchange {

    using Chainlink for Chainlink.Request;

    /// Chainlink parameters
    uint256 public volume;
    bytes32 private jobId;
    uint256 private fee;

    /// ..
    OptionPool[] internal pools;

    /// ..
    mapping (uint => bytes32) pendingRequestIds;

    /// Maps the poolId to a merkle root
    mapping (uint => bytes32) public optionPoolMerkleRoots;

    /// We keep a track of the claims mapping the merkle DNA to true/false
    mapping (bytes32 => bool) public optionPoolMerkleRootClaims;

    constructor () public ConfirmedOwner(msg.sender) {
        // Set our ChainLink configuration
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    /**
     * Provides the `OptionPool` struct data. If the index cannot be found, then we
     * will receive an empty response.
     */
    function getOptionPool(uint poolId) external view returns (OptionPool memory) {
        return pools[poolId];
    }

    /**
     * Allows our {TreasuryManager} to create an `OptionPool` from tokens that have been
     * passed in from the `deposit` function. We need to ensure that we have
     * sufficient token amounts in the contract.
     *
     * This would mean that user's would not be able to action their {Option}, which is
     * a bad thing.
     *
     * Should emit the {OptionPoolCreated} event.
     */
    function createPool(address token, uint amount, uint maxDiscount, uint expires) external returns (uint) {
        require(expires > block.timestamp, 'Pool already expired');
        require(amount != 0, 'No amount specified');

        // Create our pool
        pools.push(
            OptionPool(
                amount,          // amount
                amount,          // initialAmount
                token,           // token
                maxDiscount,     // maxDiscount
                uint64(expires)  // expires
            )
        );

        // Transfer tokens from Treasury to the pool
        require(
            ERC20(token).transferFrom(treasury, address(this), amount),
            'Unable to transfer from Treasury'
        );

        return pools.length - 1;
    }

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
    function generateAllocations(uint poolId) external returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillAllocations.selector
        );

        // Set the URL to perform the GET request on
        req.add('get', 'https://oracles.floor.xyz/generateAllocations');
        req.add('path', 'merkpleProof');

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    /**
     * Our Chainlink response will trigger this function. We will need to validate the
     * `requestId` is currently pending for the contract and then parse the `bytesData`
     * into a format through which we can create a range of `OptionAllocation`.
     *
     * We will need to return packed bytes that we can iterate through, allowing for a
     * variable length of results to be sent. With bit manipulation we can aim to keep
     * the required amount of data passed to a minimum.
     *
     * We should expect only our defined Oracle to call this method, so validation should
     * be made around this.
     */
    function fulfillAllocations(bytes32 requestId, bytes memory bytesData) external {
        /**
         * DNA is defined as:
         *
         * [allocation][reward amount][rarity][pool id]
         *      8             8           8       8
         */

        /**
         * We could store it as:
         *  keccak256([address][dna][index]) (address, bytes32, uint256) bytes256
         *
         * We could create a merkle tree that would allow us to just provide a
         * merkle proof.
         *
         * We would need the frontend call to send up the requested DNA and the index.
         *
         * We then validate against:
         *  keccak256([msg.sender][dna][index])
         *
         * We could also just allow the msg.sender to be set as the recipient so that
         * we can mint on behalf of others.
         *
         * https://soliditydeveloper.com/merkle-tree
         */

        (uint poolId, bytes32 merkleRoot) = abi.decode(bytesData, (uint, bytes32));
        optionPoolMerkleRoots[poolId] = merkleRoot;
    }

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
    function mintOptionAllocation(
        bytes32 dna,
        uint index,
        bytes32[] calldata merkleProof
    ) external {
        // Extract our pool ID from the DNA
        uint poolId = dna << 8;

        // Confirm that our pool has not expired
        require(pools[poolId].expires > block.timestamp);

        // Generate our merkle leaf (creates our wDNA)
        bytes32 node = keccak256(
            abi.encodePacked(msg.sender, dna, index)
        );

        // Confirm that the leaf is on the merkle tree
        require(
            MerkleProof.verify(merkleProof, optionPoolMerkleRoots[poolId], node),
            'Not found in merkle tree'
        );

        // Confirm that the option has not already been claimed
        require(!optionPoolMerkleRootClaims[node], 'Already claimed');

        // We can now mint our option allocation
        // IOption option = new Option(dna);
        // option.mint();

        // Mark our option as claimed
        optionPoolMerkleRootClaims[node] = true;
    }

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
    function action(uint tokenId, uint floorIn, uint tokenOut, uint approvedMovement) external {
        //
    }

    /**
     * The amount of FLOOR required to mint the specified `amount` of the `token`.
     *
     * This will call our {Treasury} to get the required price via the {PriceExecutor}.
     */
    function getRequiredFloorPrice(address token, uint amount) external returns (uint) {
        //
    }

    /**
     * Provides a list of all allocations that the user has available to be minted.
     *
     * @param recipient Address of the claimant
     */
    function claimableOptionAllocations(address recipient) external view {
        // This is run via SubGraph so no data can be returned here
    }

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
    function withdraw(uint poolId) external {
        require(pools[poolId].expires < block.timestamp, 'Not expired');
        require(pools[poolId].amount != 0, 'Empty');

        ERC20(pools[poolId].token).transfer(treasury, pools[poolId].amount);
    }

    /**
     * Allows any sender to provide ChainLink token balance to the contract. This is
     * required for the generation of our user allocations.
     *
     * This should emit the {LinkBalanceIncreased} event.
     */
    function depositLink(uint amount) external {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transferFrom(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /**
     * By default, FLOOR received from an {Option} being actioned will be burnt by
     * sending it to a NULL address. If decisions change in the future then we want
     * to be able to update the recipient address.
     *
     * Should emit {UpdatedFloorRecipient} event.
     *
     * @param newRecipient The new address that will receive exchanged FLOOR tokens
     */
    function setFloorRecipient(address newRecipient) external {
        //
    }

}
