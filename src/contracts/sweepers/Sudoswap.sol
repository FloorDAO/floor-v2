// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LSSVMPair} from 'lssvm2/LSSVMPair.sol';
import {LSSVMPairETH} from 'lssvm2/LSSVMPairETH.sol';
import {LSSVMPairERC20} from 'lssvm2/LSSVMPairERC20.sol';
import {GDACurve} from 'lssvm2/bonding-curves/GDACurve.sol';
import {LSSVMPairFactory, IERC721, IERC1155, ILSSVMPairFactoryLike} from 'lssvm2/LSSVMPairFactory.sol';

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

    /// ..
    LSSVMPairFactory public immutable pairFactory;

    /// ..
    GDACurve public immutable gdaCurve;

    /// ..
    address payable immutable treasury;

    /// ..
    mapping (address => address) public sweeperPools;

    /**
     * Defines our immutable contracts.
     */
    constructor(address payable _treasury, address payable _pairFactory, address _gdaCurve) {
        if (_treasury == address(0) || _pairFactory == address(0) || _gdaCurve == address(0)) {
            revert CannotSetNullAddress();
        }

        treasury = _treasury;
        pairFactory = LSSVMPairFactory(_pairFactory);
        gdaCurve = GDACurve(_gdaCurve);
    }

    /// ..
    function execute(address[] calldata collections, uint[] calldata amounts, bytes calldata data)
        external
        payable
        override
        nonReentrant
        returns (string memory)
    {
        // TODO: dafuq is this?
        uint alphaAndLambda;
        address propertyChecker;

        // Add support to `data` the defines 721 / 1155
        (bool[] memory is1155) = abi.decode(data, (bool[]));

        // TODO: Does the GDA Curve max out at the ETH balance in pool? Does it work
        // on a timestamp basis or would it just restart when addition ETH supplied?
        uint128 initialSpotPrice = 0.1 ether;

        // Loop through collections
        for (uint i; i < collections.length; ++i) {
            // Check if a sweeper pool already exists. If it doesn't then we need
            // to create it with sufficient ETH.
            if (sweeperPools[collections[i]] == address(0)) {
                uint[] memory empty;
                uint128 delta = (uint128(alphaAndLambda) << 48) + uint128(uint48(block.timestamp));

                LSSVMPair pair;
                if (is1155[i] == false) {
                    pair = pairFactory.createPairERC721ETH{value: amounts[i]}({
                        _nft: IERC721(collections[i]),
                        _bondingCurve: gdaCurve,
                        _assetRecipient: treasury,
                        _poolType: LSSVMPair.PoolType.TOKEN,
                        _delta: delta,
                        _fee: 0,
                        _spotPrice: initialSpotPrice,
                        _propertyChecker: propertyChecker,
                        _initialNFTIDs: empty
                    });
                } else {
                    pair = pairFactory.createPairERC1155ETH{value: msg.value}({
                        _nft: IERC1155(collections[i]),
                        _bondingCurve: gdaCurve,
                        _assetRecipient: treasury,
                        _poolType: LSSVMPair.PoolType.TOKEN,
                        _delta: delta,
                        _fee: 0,
                        _spotPrice: initialSpotPrice,
                        _nftId: 0, // TODO: Can only supply a single ERC1155 token ID?
                        _initialNFTBalance: 0
                    });
                }

                sweeperPools[collections[i]] = address(pair);
            }
            // If the sweeper _does_ already exist, then we can just fund it with
            // additional ETH.
            else {
                // TODO: Do we need to alter the delta at this point?

                // Deposit ETH to pair
                (bool sent,) = sweeperPools[collections[i]].call{value: amounts[i]}('');
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
    function endSweep(address recipient, address pool) public onlyOwner {
        // LSSVMPairETH(payable(address(pair))).withdrawETH(amount);
        // recipient.safeTransferETH(amount);
        // emit WithdrawETH(pair, amount, recipient);
    }

    /**
     * Specify that anyone can run this sweeper.
     */
    function permissions() public pure override returns (bytes32) {
        return '';
    }

    /**
     * Allows our contract to receive dust ETH back from our sweep.
     */
    receive() external payable {}
}
