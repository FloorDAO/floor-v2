// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';


/**
 * A mock for testing code that relies on Chainlink VRFCoordinatorV2.
 */
contract VRFCoordinatorV2Mock {

    uint96 public immutable BASE_FEE;
    uint96 public immutable GAS_PRICE_LINK;
    address public immutable LINK_TOKEN;

    uint s_nextRequestId;


    /**
     * Set up our contract parameters.
     */
    constructor(uint96 _baseFee, uint96 _gasPriceLink, address _linkToken) {
        BASE_FEE = _baseFee;
        GAS_PRICE_LINK = _gasPriceLink;
        LINK_TOKEN = _linkToken;
    }


    /**
     * @notice fulfillRandomWordsWithOverride allows the user to pass in their own random words.
     *
     * @param _requestId The request to fulfill
     * @param _consumer The VRF randomness consumer to send the result to
     * @param _numWords The number of words to generate
     */
    function fulfillRandomWords(uint256 _requestId, address _consumer, uint256 _numWords) public {
        // We need to ensure that we received enough words
        require(_numWords != 0, 'Invalid number of words requested');

        // Generate a series of random uints based on the requestId and loop
        // iteration.
        uint[] memory _words = new uint[](_numWords);
        for (uint i; i < _numWords;) {
            _words[i] = uint(keccak256(abi.encode(_requestId, i)));
            unchecked { ++i; }
        }

        // Send our call back to our base contract (referenced by `_consumer`) using
        // the `rawFulfillRandomWords` function selector. For our mock we just allow
        // for a large amount of gas to ensure it lands.
        VRFConsumerBaseV2 v;
        bytes memory callReq = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, _requestId, _words);
        (bool success, ) = _consumer.call{gas: 250000}(callReq);
        require(success, 'Unable to send response');

        // We now take a LINK payment to fund the transaction.
        uint96 payment = BASE_FEE * GAS_PRICE_LINK;
        require(
            IERC20(LINK_TOKEN).transferFrom(_consumer, address(this), payment),
            'Insufficient balance'
        );
    }


    /**
     * As this is a mock, we immediately send our completed transaction. Normally
     * this would wait for a number of confirmations and it would be sent back
     * asynchronously.
     */
    function requestRandomWords(uint32 _callbackGasLimit, uint16 _requestConfirmations, uint32 _numWords) external returns (uint requestId) {
        // Bump up our seeding variable
        requestId = s_nextRequestId++;

        // We can immediately call our random words to be fulfilled to the caller
        fulfillRandomWords(requestId, msg.sender, _numWords);

        // Return our requestId, as the true contract would
        return requestId;
    }


    /**
     * We set a static request price of 0.01.
     */
    function calculateRequestPrice(uint32 _callbackGasLimit) external pure returns (uint) {
        return 10e16;
    }


    /**
     * This would normally be used to monitor subscription balances, but we aren't
     * interested in monitoring this in our mock.
     */
    function onTokenTransfer(address sender, uint amount, bytes calldata data) external pure {
        //
    }

    /**
     * Helper function to return the last request ID sent.
     */
    function lastRequestId() external view returns (uint) {
        return s_nextRequestId;
    }

}
