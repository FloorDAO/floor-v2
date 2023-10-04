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
 *
 *
 * @dev Only the recipient can withdraw ETH. This would mean that it would have to
 * be the {Treasury} that makes the call. If this is the case, then we should be able
 * to run this via an {Action}. We will need to test this theory.
 */
contract SudoswapSweeper is ISweeper, Ownable, ReentrancyGuard {

    /// External Sudoswap contracts
    LSSVMPairFactory public immutable pairFactory;
    GDACurve public immutable gdaCurve;

    /// Contract that will detect valid NFT properties
    address public immutable propertyChecker;

    /// The address of our {Treasury} that will receive assets
    address payable immutable treasury;

    /// A mapping of our collections to their sweeper pool, allowing us to update
    /// and deposit additional ETH over time.
    mapping (address => LSSVMPairETH) public sweeperPools;

    /// Controls how fast the price decays
    // uint80 internal constant alphaAndLambda = 132039004365459280618771543;
    uint80 internal immutable alphaAndLambda;

    /// Our initial spot price is set as a low value that builds over time. This
    /// amount should be below floor of our lowest asset.
    uint128 public constant initialSpotPrice = 0.1 ether;

    /**
     * Defines our immutable contracts.
     */
    constructor(
        address payable _treasury,
        address payable _pairFactory,
        address _gdaCurve,
        address _propertyChecker
    ) {
        // Ensure
        if (_treasury == address(0) || _pairFactory == address(0) || _gdaCurve == address(0)) {
            revert CannotSetNullAddress();
        }

        treasury = _treasury;
        pairFactory = LSSVMPairFactory(_pairFactory);
        gdaCurve = GDACurve(_gdaCurve);
        propertyChecker = _propertyChecker;

        // alpha = bound(alpha, 1e9 + 1, 2e9);
        // lambda = bound(lambda, 0, type(uint40).max);
        alphaAndLambda = uint80(((1.05e9) << 40) + 2e9);
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
                    propertyChecker,          // _propertyChecker
                    new uint[](0)             // _initialNFTIDs
                );
            }
            // If the sweeper _does_ already exist, then we can just fund it with
            // additional ETH.
            else {
                // When we provide additional ETH, we need to reset the spot price and delta
                // to ensure that we aren't sweeping above market price.
                LSSVMPairETH pair = sweeperPools[collections[i]];
                if (pair.spotPrice() > payable(pair).balance) {
                    pair.changeSpotPrice(uint128(payable(pair).balance));
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
     * Allow the contract to receive ETH back during the `endSweep` call.
     */
    receive() external payable {}
}
