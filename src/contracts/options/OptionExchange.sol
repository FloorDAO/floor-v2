// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';

import './Option.sol';
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

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint[] randomWords;
    }

    /// ..
    OptionPool[] internal pools;

    /// ..
    mapping (uint => RequestStatus) s_requests;

    /// Maps the poolId to a merkle root
    mapping (uint => bytes32) public optionPoolMerkleRoots;

    /// We keep a track of the claims mapping the merkle DNA to true/false
    mapping (bytes32 => bool) public optionPoolMerkleRootClaims;

    /// ..
    address public immutable treasury;

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
    uint32 numWords = 3;

    // Address LINK - hardcoded for Goerli
    // address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

    // address WRAPPER - hardcoded for Goerli
    // address wrapperAddress = 0x708701a1DfF4f478de54383E49a627eD4852C816;


    /**
     *
     */
    constructor (address _treasury, address _linkAddress, address _wrapperAddress) ConfirmedOwner(msg.sender) VRFV2WrapperConsumerBase(_linkAddress, _wrapperAddress) {
        treasury = _treasury;
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
    function createPool(address token, uint amount, uint16 maxDiscount, uint64 expires) external returns (uint) {
        require(expires > block.timestamp, 'Pool already expired');
        require(amount != 0, 'No amount specified');

        // Create our pool
        pools.push(
            OptionPool(
                amount,       // amount
                amount,       // initialAmount
                token,        // token
                maxDiscount,  // maxDiscount
                expires,      // expires
                false         // initialised
            )
        );

        // Transfer tokens from Treasury to the pool
        require(
            IERC20(token).transferFrom(treasury, address(this), amount),
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
            randomWord: 0,
            fulfilled: false
        });

        // Set the request ID against our pool
        pools[poolId].requestId = requestId;
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
    function fulfillRandomWords(uint _requestId, uint[] memory _randomWords) internal {
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

        // Confirm that our request is valid
        require(s_requests[_requestId].paid > 0, 'Request not found');

        // Update our request to apply the returned random values
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;

        uint poolId = 0;

        uint MIN_SHARE = 1;
        uint MAX_SHARE = 20;
        uint MIN_DISCOUNT = 0;
        uint MAX_DISCOUNT = pools[poolId].maxDiscount;
        uint SHARE_DEVIATION = 3;
        uint DISCOUNT_DEVIATION = 3;

        // Generate an array of options
        uint i;
        uint allocatedAmount;
        bytes32[] memory options = new bytes32[];

        while (allocatedAmount < pools[poolId].amount) {
            i += 1;

            uint share = 2 * (
                getBellValue(
                    _randomWords[0],
                    _randomWords[1] + i,
                    MIN_SHARE + (MAX_SHARE / 2),
                    MAX_SHARE * 1.5,
                    SHARE_DEVIATION,
                    0.5
                ) - MAX_SHARE
            );

            uint discount = 2 * (
                getBellValue(
                    _randomWords[0],
                    _randomWords[2] + i,
                    MIN_DISCOUNT + (MAX_DISCOUNT / 2),
                    MAX_DISCOUNT * 1.5,
                    SHARE_DEVIATION,
                    0.5
                ) - MAX_DISCOUNT
            );

            if (share == 0) {
                share = 1;
            }

            if ((allocatedAmount + share) > pools[poolId].amount) {
                share = pools[poolId].amount - allocatedAmount;
            }

            // Create our DNA
            options.push(
                abi.encodePacked(
                    bytes8(share),
                    bytes8(discount),
                    bytes8(rarity_score(share, discount)),
                    bytes8(poolId)
                )
            );

            allocatedAmount += share;
        }

        // Generate our merkle tree against allocations
        // https://github.com/dmfxyz/murky
        Merkle merkle = new Merkle();

        // Create our merkle data to be the length of our options
        bytes32[] memory data = new bytes32[](options.length);

        // Get members of the vault and assign them a start and end position based
        // on percentage ownership.
        for (i = 0; i < options.length; ++i) {
            bytes32 wDNA = abi.encodePacked(
                0x498E93Bc04955fCBAC04BCF1a3BA792f01Dbaa96,
                options[i],
                poolId
            );

            // Emit stuff

            // Add to our merkle tree
            data[i] = wDNA;
        }

        // Set our merkle root against the pool
        optionPoolMerkleRoots[poolId] = merkle.getRoot(data);

        // Set our pool to initialised
        pools[poolId].initialised = true;
    }




    function rarity_score(uint share, uint discount) internal returns (uint) {
        uint share_rarity = 100 - (((share - 1) / (20 - 1)) * 100) * 1.25; // We want more rating weight towards discount
        uint discount_rarity = 100 - (((discount - 0) / (10 - 0)) * 100);

        return (share_rarity + discount_rarity) / 200;
    }



    function getBellValue(uint seed, uint seed2, uint min, uint max, uint std_deviation, uint step) public returns (uint) {
        uint rand1 = seed << seed2 / type(uint).max;
        uint rand2 = seed >> seed2 / type(uint).max;
        uint gaussian_number = sqrt(-2 * log(rand1)) * cos(2 * M_PI * rand2);

        uint mean = (max + min) / 2;

        int random_number = (gaussian_number * std_deviation) + mean;
        random_number = round(random_number / step) * step;

        if (random_number < 0) {
            random_number *= -1;
        }

        if (random_number < min) {
            return min;
        }

        if (random_number > max) {
            return max;
        }

        return random_number;
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
     *
     * If there is substantial assets remaining, we could bypass our `withdraw` call and
     * instead just call `createPool` again with the same token referenced.
     */
    function withdraw(uint poolId) external {
        require(pools[poolId].expires < block.timestamp, 'Not expired');
        require(pools[poolId].amount != 0, 'Empty');

        IERC20(pools[poolId].token).transfer(treasury, pools[poolId].amount);
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
            link.transferFrom(msg.sender, address(this), amount),
            "Unable to transfer"
        );
    }


    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
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


    /**
     *
     */
    function getRequestStatus(uint _requestId) external view returns (uint256 paid, bool fulfilled, uint randomWord) {
        require(s_requests[_requestId].paid > 0, 'Request not found');
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWord);
    }



}
