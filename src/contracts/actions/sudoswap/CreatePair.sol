// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICurve} from '@sudoswap/bonding-curves/ICurve.sol';
import {LSSVMPairFactory} from '@sudoswap/LSSVMPairFactory.sol';
import {ERC20, LSSVMPair} from '@sudoswap/LSSVMPair.sol';

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {Action} from '@floor/actions/Action.sol';

/**
 * New pairs for the sudoswap AMM are created with the LSSVMPairFactory. LPs will call
 * either createPairETH or createPairERC20 depending on their token type (i.e. if they
 * wish to utilize ETH or an ERC20). This will deploy a new LSSVMPair contract.
 *
 * Each pair has one owner (initially set to be the caller), and multiple pools for the
 * same token and NFT pair can exist, even for the same owner. This is due to each pair
 * having its own potentially different spot price and bonding curve.
 *
 * @dev https://docs.sudoswap.xyz/reference/pair-creation/
 */
contract SudoswapCreatePair is Action {
    using SafeERC20 for IERC20;

    /**
     * @param token The ERC20 to stake against the NFT. Zero if ETH will be paired.
     * @param nft The NFT contract of the collection the pair trades
     * @param bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
     * @param poolType TOKEN, NFT, or TRADE
     * @param delta The delta value used by the bonding curve. The meaning of delta depends
     * on the specific curve.
     * @param fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
     * @param spotPrice The initial selling spot price
     * @param initialTokenBalance The initial token balance sent from the sender to the new pair. This
     * should be zero if ETH is paired
     * @param initialNftIds The list of IDs of NFTs to transfer from the sender to the pair
     */
    struct ActionRequest {
        address token;
        address nft;
        address bondingCurve;
        LSSVMPair.PoolType poolType;
        uint128 delta;
        uint96 fee;
        uint128 spotPrice;
        uint initialTokenBalance;
        uint[] initialNftIds;
    }

    /**
     * Defines a partial ActionRequest struct as we aren't able to parse the `initialNftIds`
     * parameter from the calldata due to it being an array. This normally wouldn't be a
     * problem, and we could parse the parameters individually, but in this contract it would
     * overflow the parameter stack.
     */
    struct PartialActionRequest {
        address token;
        address nft;
        address bondingCurve;
        LSSVMPair.PoolType poolType;
        uint128 delta;
        uint96 fee;
        uint128 spotPrice;
        uint initialTokenBalance;
    }

    /// Store our pair factory
    LSSVMPairFactory public immutable pairFactory;

    /**
     * We assign any variable contract addresses in our constructor, allowing us
     * to have multiple deployed actions if any parameters change.
     */
    constructor(address payable _pairFactory) {
        pairFactory = LSSVMPairFactory(_pairFactory);
    }

    /**
     * Creates a new Sudoswap pairing.
     *
     * @param _request Packed bytes that will map to our `ActionRequest` struct
     *
     * @return uint Integer representation of the created pair address
     */
    function execute(bytes calldata _request) public payable override whenNotPaused sendEvent(_request) returns (uint) {
        // Unpack the request bytes data into individual variables, as mapping it directly
        // to the struct is buggy due to memory -> storage array mapping.
        PartialActionRequest memory request = abi.decode(_request, (PartialActionRequest));
        (,,,,,,,,uint[] memory initialNftIds) = abi.decode(_request, (address, address, address, uint8, uint128, uint96, uint128, uint, uint[]));

        // Validate our provided pool type
        require(request.poolType == LSSVMPair.PoolType.NFT || request.poolType == LSSVMPair.PoolType.TRADE, 'Unknown pool type');

        // Transfer our NFT IDs to the action as the pair factory requires them to be
        // transferred from the immediate sender.
        IERC721 _nft = IERC721(request.nft);

        // We skip parsing the length outside of the loop as this takes us over our
        // variable limit.
        for (uint i; i < initialNftIds.length;) {
            _nft.transferFrom(msg.sender, address(this), initialNftIds[i]);
            _nft.approve(address(pairFactory), initialNftIds[i]);
            unchecked {
                ++i;
            }
        }

        // Determine the asset recipient, based on the pool type. The address that will receive the
        // assets traders give during trades. If set to address(0), assets will be sent to the pool
        // address. Not available to TRADE pools.
        address payable assetRecipient;
        if (request.poolType == LSSVMPair.PoolType.NFT) {
            assetRecipient = payable(msg.sender);
        }

        // Prepare to capture a Pair through either of our creation methods
        LSSVMPair pair;

        // If we have no token provided, then we will be backing the NFT value
        // with ETH.
        if (request.token == address(0)) {
            pair = pairFactory.createPairETH{value: msg.value}({
                _nft: _nft,
                _bondingCurve: ICurve(request.bondingCurve),
                _assetRecipient: assetRecipient,
                _poolType: request.poolType,
                _delta: request.delta,
                _fee: request.fee,
                _spotPrice: request.spotPrice,
                _initialNFTIDs: initialNftIds
            });
        } else {
            // For this pairing, we additionally need to transfer our ERC20 token
            IERC20(request.token).safeTransferFrom(msg.sender, address(this), request.initialTokenBalance);
            IERC20(request.token).approve(address(pairFactory), request.initialTokenBalance);

            // When we have an ERC20 defined, then we pair ERC20 <-> ERC721
            pair = pairFactory.createPairERC20(
                LSSVMPairFactory.CreateERC20PairParams({
                    token: ERC20(request.token),
                    nft: _nft,
                    bondingCurve: ICurve(request.bondingCurve),
                    assetRecipient: assetRecipient,
                    poolType: request.poolType,
                    delta: request.delta,
                    fee: request.fee,
                    spotPrice: request.spotPrice,
                    initialNFTIDs: initialNftIds,
                    initialTokenBalance: request.initialTokenBalance
                })
            );
        }

        // Transfer the ownership of the created pair to the caller
        pair.transferOwnership(msg.sender);

        // Return our integer address equivalent
        return uint(uint160(address(pair)));
    }

    /**
     * Decodes bytes data from an `ActionEvent` into the `ActionRequest` struct
     */
    function parseInputs(bytes memory _callData) public pure returns (ActionRequest memory params) {
        params = abi.decode(_callData, (ActionRequest));
    }

    /**
     * To avoid a variable "Stack too long" issues we had to emit this event via a modifier.
     */
    modifier sendEvent(bytes memory _request) {
        _;
        emit ActionEvent('SudoswapCreatePair', _request);
    }
}
