// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LSSVMPair} from 'lssvm2/LSSVMPair.sol';
import {LSSVMPairETH} from 'lssvm2/LSSVMPairETH.sol';
import {LSSVMPairERC20} from 'lssvm2/LSSVMPairERC20.sol';
import {GDACurve} from 'lssvm2/bonding-curves/GDACurve.sol';
import {LSSVMPairFactory, IERC721, IERC1155, ILSSVMPairFactoryLike} from 'lssvm2/LSSVMPairFactory.sol';
import {IPropertyChecker} from 'lssvm2/property-checking/IPropertyChecker.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import {CannotSetNullAddress, TransferFailed} from '@floor/utils/Errors.sol';

import {ISweeper} from '@floor-interfaces/actions/Sweeper.sol';

/**
 * Takes ETH and deposits it into individual pools against NFT collections. This allows
 * the sale price to be put onto a curve, allowing external parties to sell into it with
 * instant liquidity. When a purchase is made, the price will dip slightly and continue
 * to rise.
 *
 * When additional ETH is deposited against a pool that already exists it will reset the
 * ETH price to the previously held ETH balance and then restart. This prevents the curve
 * rising without sufficient ETH and then allowing for an over generous trade when more
 * ETH is deposited.
 *
 * @dev Only the recipient can withdraw ETH. This would mean that it would have to
 * be the {Treasury} that makes the call. If this is the case, then we should be able
 * to run this via an {Action}. We will need to test this theory.
 *
 * @dev Alpha/lambda graphing calculator can be found here:
 * https://www.desmos.com/calculator/03pdgzfpo4
 */
contract SudoswapSweeper is ISweeper, Ownable, ReentrancyGuard {

    /// External Sudoswap contracts
    LSSVMPairFactory public immutable pairFactory;
    GDACurve public immutable gdaCurve;

    /// The address of our {Treasury} that will receive assets
    address payable immutable treasury;

    /// A mapping of our collections to their sweeper pool, allowing us to update
    /// and deposit additional ETH over time.
    mapping (address => LSSVMPairETH) public sweeperPools;

    /// Controls how fast the price decays
    uint80 internal alphaAndLambda;

    /// Our initial spot price is set as a low value that builds over time. This
    /// amount should be below floor of our lowest asset.
    uint128 public constant initialSpotPrice = 0.01 ether;

    /**
     * Defines our immutable contracts.
     */
    constructor(address payable _treasury, address payable _pairFactory, address _gdaCurve) {
        // Ensure that we don't reference null addresses
        if (_treasury == address(0) || _pairFactory == address(0) || _gdaCurve == address(0)) {
            revert CannotSetNullAddress();
        }

        // Register our contracts
        treasury = _treasury;
        pairFactory = LSSVMPairFactory(_pairFactory);
        gdaCurve = GDACurve(_gdaCurve);

        // Set our default alpha/lambda value
        setAlphaLambda(1.05e9, 0.000005e9);
    }

    /**
     * Deposits ETH into a Sudoswap pool position to purchase ERC721 tokens over time. This
     * uses a GDA curve to gradually increase the offered price over time.
     *
     * @dev This execution does not support ERC1155
     */
    function execute(address[] calldata collections, uint[] calldata amounts, bytes calldata /* data */)
        external
        payable
        override
        nonReentrant
        returns (string memory)
    {
        // Loop through collections
        for (uint i; i < collections.length; ++i) {
            // Check if a sweeper pool already exists. If it doesn't then we need
            // to create it with sufficient ETH.
            if (address(sweeperPools[collections[i]]) == address(0)) {
                // Map our collection to a newly created pair
                sweeperPools[collections[i]] = pairFactory.createPairERC721ETH{value: amounts[i]}(
                    IERC721(collections[i]),  // _nft
                    gdaCurve,                 // _bondingCurve
                    treasury,                 // _assetRecipient
                    LSSVMPair.PoolType.TOKEN, // _poolType
                    (uint128(alphaAndLambda) << 48) + uint128(uint48(block.timestamp)), // _delta
                    0,                        // _fee
                    initialSpotPrice,         // _spotPrice
                    address(0),               // _propertyChecker
                    new uint[](0)             // _initialNFTIDs
                );
            }
            // If the sweeper _does_ already exist, then we can just fund it with
            // additional ETH.
            else {
                // When we provide additional ETH, we need to reset the spot price and delta
                // to ensure that we aren't sweeping above market price.
                LSSVMPairETH pair = sweeperPools[collections[i]];

                uint pairBalance = payable(pair).balance;
                if (pair.spotPrice() > pairBalance) {
                    // If the pair balance is below the initial starting threshold, then we will
                    // reset the spot price to that as a minimum.
                    if (pairBalance < initialSpotPrice) {
                        pairBalance = initialSpotPrice;
                    }

                    // Update the spot price to either the current pair balance (before deposit)
                    // or to the initial spot price defined by the contract.
                    pair.changeSpotPrice(uint128(pairBalance));

                    // Update the delta back to the initial price
                    pair.changeDelta((uint128(alphaAndLambda) << 48) + uint128(uint48(block.timestamp)));
                }

                // Deposit ETH to pair
                (bool sent,) = payable(pair).call{value: amounts[i]}('');
                if (!sent) revert TransferFailed();
            }
        }

        // Return an empty string as no message to store
        return '';
    }

    /**
     * Withdraws any remaining ETH from the pool and transfers it to a recipient. This
     * will almost always be the {Treasury}.
     *
     * @dev This will be run as a {Treasury} {Action}.
     */
    function endSweep(address collection) public onlyOwner {
        // Withdraw all ETH from the pool
        sweeperPools[collection].withdrawAllETH();

        // Transfer it to our Treasury
        (bool sent,) = treasury.call{value: payable(address(this)).balance}('');
        if (!sent) revert TransferFailed();
    }

    /**
     * Specify that anyone can run this sweeper.
     */
    function permissions() public pure override returns (bytes32) {
        return '';
    }

    /**
     * Allows us to set a new alpha lambda value that will affect how quickly the ETH
     * value will rise and fall.
     */
    function setAlphaLambda(uint alpha, uint lambda) public onlyOwner {
        require(alpha > 1e9 && alpha <= 2e9);
        require(lambda >= 0 && lambda <= type(uint40).max);

        alphaAndLambda = uint80((alpha << 40) + lambda);
    }

    /**
     * A helper function that will assist in calculating an alpha lambda. This can be used
     * in conjunection with the `setAlphaLambda` function to get a desired value.
     *
     * @dev Magic lambda for 2x increase or 50% decrease per day is when _lambda = 11574
     * @dev Magic lambda for 1.5x increase or 33% decrease per day is when _lambda = 6770
     * @dev Magic lambda for 1.33x increase or 25% decrease per day is when _lambda = 4802
     */
    function getPackedDelta(uint40 _alpha, uint40 _lambda, uint48 _time) public pure returns (uint128) {
        return ((uint128(_alpha) << 88)) | ((uint128(_lambda) << 48)) | uint128(_time);
    }

    /**
     * Allow the contract to receive ETH back during the `endSweep` call.
     */
    receive() external payable {}
}
