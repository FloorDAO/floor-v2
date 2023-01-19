// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@chainlink/contracts/src/v0.8/ConfirmedOwner.sol';
import '@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol';

import '@murky/Merkle.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import './Option.sol';
import './OptionDistributionWeightingCalculator.sol';
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
contract OptionExchange is ConfirmedOwner, IOptionExchange, VRFV2WrapperConsumerBase {
    /// Maintain a list of options that we will append and delete
    /// from during the generation process.
    bytes32[] _options;

    /// Our Option Distribution Weighting ladder is stored as an external
    /// contract to allow ongoing optimisation and manipulation of the
    /// desired algorithm. All it requires is for us to be able to send
    /// a seeded `get` call to return a value.
    OptionDistributionWeightingCalculator public weighting;

    /// ..
    OptionPool[] internal pools;

    /// ..
    mapping(uint => RequestStatus) public s_requests;

    /// Maps the poolId to a merkle root
    mapping(uint => bytes32) public optionPoolMerkleRoots;

    /// We keep a track of the claims mapping the merkle DNA to true/false
    mapping(bytes32 => bool) public optionPoolMerkleRootClaims;

    /// ..
    address public immutable treasury;
    address public immutable linkAddress;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 16;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
    uint32 numWords = 2;

    /**
     * ...
     */
    constructor(address _treasury, address _linkAddress, address _wrapperAddress)
        ConfirmedOwner(msg.sender)
        VRFV2WrapperConsumerBase(_linkAddress, _wrapperAddress)
    {
        linkAddress = _linkAddress;
        treasury = _treasury;
    }

    /**
     * Allows an approved caller to update the weighting calculator contract.
     */
    function setOptionDistributionWeightingCalculator(address _weighting) external {
        weighting = OptionDistributionWeightingCalculator(_weighting);
        emit DistributionCalculatorUpdated(_weighting);
    }

    /**
     * Provides the `OptionPool` struct data. We sense check that the pool exists
     * and revert if it does not.
     */
    function getOptionPool(uint poolId) external view returns (OptionPool memory) {
        require(poolId < pools.length, 'Pool does not exist');
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
    function createPool(address token, uint amount, uint16 maxDiscount, uint64 expires)
        external
        returns (uint poolId)
    {
        // Sense check our provided data
        require(expires > block.timestamp, 'Pool already expired');
        require(amount != 0, 'No amount specified');
        require(maxDiscount <= 100, 'Max discount over 100%');

        // Create our pool
        pools.push(
            OptionPool(
                amount, // amount
                amount, // initialAmount
                token, // token
                maxDiscount, // maxDiscount
                expires, // expires
                false, // initialised
                0 // requestId
            )
        );

        // Transfer tokens from Treasury to the pool
        require(IERC20(token).transferFrom(treasury, address(this), amount), 'Unable to transfer from Treasury');

        poolId = pools.length - 1;
        emit OptionPoolCreated(poolId);
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
    function generateAllocations(uint poolId) external returns (uint requestId) {
        // Confirm that our pool exists
        require(poolId < pools.length, 'Pool does not exist');

        // Validate our pool
        require(pools[poolId].amount != 0, 'Pool has no amount');
        require(pools[poolId].expires > block.timestamp, 'Pool already expired');

        // Confirm we don't already have a pending request for this pool
        require(pools[poolId].requestId == 0, 'Pool has existing request');

        // Generate our random seed to trigger the process
        requestId = requestRandomness(callbackGasLimit, requestConfirmations, numWords);

        // Store our request so that we can continue to monitor progress
        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false,
            poolId: poolId
        });

        // Set the request ID against our pool
        pools[poolId].requestId = requestId;

        // Detect if our LINK balance is low and emit appropriate events
        _detectLowLinkBalance();
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
    function fulfillRandomWords(uint _requestId, uint[] memory _randomWords) internal virtual override {
        // Confirm that our request is valid
        require(s_requests[_requestId].paid > 0, 'Request not found');

        // Update our request to apply the returned random values
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        // Confirm that we have enough words returned
        require(_randomWords.length >= numWords, 'Insufficient words returned');

        // Get our pool information
        OptionPool memory pool = pools[s_requests[_requestId].poolId];

        // Map our share allocation, which will always be < 100
        uint allocatedAmount;

        // Whilst we have remaining allocation of the pool amount assigned, create options
        uint i;
        while (allocatedAmount < 100) {
            unchecked {
                ++i;
            }

            // Get our weighted share allocation. If it is equal to 0, then
            // we set it to 1 as the minimum value.
            uint share = weighting.getShare(_randomWords[0] / 10000 * i);

            // Get our discount allocation
            uint discount = weighting.getDiscount(_randomWords[1] / 10000 * i);

            // If our share allocation puts us over the total pool amount then
            // we just need provide the user the maximum remaining.
            if (allocatedAmount + share > 100) {
                share = 100 - allocatedAmount;
            }

            // Create our DNA; it is defined as:
            // [allocation][reward amount][rarity][pool id]
            _options.push(
                bytes32(
                    abi.encodePacked(
                        uint8(share),
                        uint8(discount),
                        rarityScore(share, discount, pool.maxDiscount),
                        uint8(s_requests[_requestId].poolId)
                    )
                )
            );

            // Add our share to the allocated amount
            allocatedAmount += share;
        }

        // Generate our merkle tree against allocations
        // https://github.com/dmfxyz/murky
        Merkle merkle = new Merkle();

        // Create our merkle data to be the length of our options
        bytes32[] memory data = new bytes32[](i);

        // Get members of the vault and assign them a start and end position based
        // on percentage ownership.
        for (uint k; k < i;) {
            // Wrap our DNA and add to our merkle tree data leaves
            data[k] = bytes32(
                abi.encodePacked(
                    // TODO: Dynamically select user
                    0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96,
                    _options[k],
                    s_requests[_requestId].poolId
                )
            );

            // Delete our _options value for gas saves
            delete _options[k];

            unchecked {
                ++k;
            }
        }

        // Set our merkle root against the pool
        optionPoolMerkleRoots[s_requests[_requestId].poolId] = merkle.getRoot(data);

        // Set our pool to initialised
        pools[s_requests[_requestId].poolId].initialised = true;

        emit RequestFulfilled(_requestId, merkle.getRoot(data));
    }

    /**
     * This wants to return a range from 0 - 100 to define rarity. A lower rarity
     * value will be rarer, whilst a higher value will be more common.
     */
    function rarityScore(uint share, uint discount, uint maxDiscount) public pure returns (uint8) {
        uint x = ((share + discount) * 10000) / (20 + maxDiscount);
        return uint8(x / 100);
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
    function mintOptionAllocation(bytes32 dna, uint index, bytes32[] calldata merkleProof) external {
        // Extract our pool ID from the DNA
        uint poolId = uint(dna << 8);

        // Confirm that our pool has not expired
        require(pools[poolId].expires > block.timestamp);

        // Generate our merkle leaf (creates our wDNA)
        bytes32 node = keccak256(abi.encodePacked(msg.sender, dna, index));

        // Confirm that the leaf is on the merkle tree
        require(MerkleProof.verify(merkleProof, optionPoolMerkleRoots[poolId], node), 'Not found in merkle tree');

        // Confirm that the option has not already been claimed
        require(!optionPoolMerkleRootClaims[node], 'Already claimed');

        // We can now mint our option allocation
        Option option = new Option();
        option.mint(msg.sender, dna);

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
     */
    function withdraw(uint poolId) external {
        require(pools[poolId].expires < block.timestamp, 'Not expired');
        require(pools[poolId].amount != 0, 'Empty');

        IERC20(pools[poolId].token).transfer(treasury, pools[poolId].amount);

        emit OptionPoolClosed(poolId);
    }

    /**
     * Allows any sender to provide ChainLink token balance to the contract. This is
     * required for the generation of our user allocations.
     *
     * This should emit the {LinkBalanceIncreased} event.
     */
    function depositLink(uint amount) external {
        require(IERC20(linkAddress).transferFrom(msg.sender, address(this), amount), 'Unable to transfer');

        emit LinkBalanceIncreased(msg.sender, amount);
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
        emit UpdatedFloorRecipient(newRecipient);
    }

    /**
     *
     */
    function _detectLowLinkBalance() internal {
        uint linkBalance = IERC20(linkAddress).balanceOf(address(this));
        if (linkBalance < 10 ether) {
            emit LinkBalanceLow(linkBalance);
        }
    }

    /**
     *
     */
    function getRequestStatus(uint _requestId)
        external
        view
        returns (uint paid, bool fulfilled, uint[] memory randomWord)
    {
        require(s_requests[_requestId].paid > 0, 'Request not found');
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }
}
