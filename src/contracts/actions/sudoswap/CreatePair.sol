// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ICurve} from '@sudoswap/bonding-curves/ICurve.sol';
import {LSSVMPairFactory} from '@sudoswap/LSSVMPairFactory.sol';
import {ERC20, LSSVMPair} from '@sudoswap/LSSVMPair.sol';

import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {IAction} from '@floor-interfaces/actions/Action.sol';

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
contract SudoswapCreatePair is IAction {
    /**
     * @param token The ERC20 to stake against the NFT. Zero if ETH will be paired.
     * @param _nft The NFT contract of the collection the pair trades
     * @param _bondingCurve The bonding curve for the pair to price NFTs, must be whitelisted
     * @param _assetRecipient The address that will receive the assets traders give during trades.
     * If set to address(0), assets will be sent to the pool address. Not available to TRADE pools.
     * @param _poolType TOKEN, NFT, or TRADE
     * @param _delta The delta value used by the bonding curve. The meaning of delta depends
     * on the specific curve.
     * @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
     * @param _spotPrice The initial selling spot price
     * @param _initialTokenBalance The initial token balance sent from the sender to the new pair. This
     * should be zero if ETH is paired
     * @param _initialNftIds The list of IDs of NFTs to transfer from the sender to the pair
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
    function execute(bytes calldata _request) public payable returns (uint) {
        // Unpack the request bytes data into individual variables, as mapping it directly
        // to the struct is buggy due to memory -> storage array mapping.
        (
            address token,
            address nft,
            address bondingCurve,
            uint8 _poolType,
            uint128 delta,
            uint96 fee,
            uint128 spotPrice,
            uint initialTokenBalance,
            uint[] memory initialNftIds
        ) = abi.decode(_request, (address, address, address, uint8, uint128, uint96, uint128, uint, uint[]));

        // Cast our integer to a PoolType
        LSSVMPair.PoolType poolType = LSSVMPair.PoolType(_poolType);

        // Validate our provided pool type
        require(poolType == LSSVMPair.PoolType.NFT || poolType == LSSVMPair.PoolType.TRADE, 'Unknown pool type');

        // Transfer our NFT IDs to the action as the pair factory requires them to be
        // transferred from the immediate sender.
        IERC721 _nft = IERC721(nft);

        // We skip parsing the length outside of the loop as this takes us over our
        // variable limit.
        for (uint i; i < initialNftIds.length;) {
            _nft.transferFrom(msg.sender, address(this), initialNftIds[i]);
            _nft.approve(address(pairFactory), initialNftIds[i]);
            unchecked {
                ++i;
            }
        }

        // Determine the asset recipient, based on the pool type
        address payable assetRecipient;
        if (poolType == LSSVMPair.PoolType.NFT) {
            assetRecipient = payable(msg.sender);
        }

        // Prepare to capture a Pair through either of our creation methods
        LSSVMPair pair;

        // If we have no token provided, then we will be backing the NFT value
        // with ETH.
        if (token == address(0)) {
            pair = pairFactory.createPairETH{value: msg.value}({
                _nft: _nft,
                _bondingCurve: ICurve(bondingCurve),
                _assetRecipient: assetRecipient,
                _poolType: poolType,
                _delta: delta,
                _fee: fee,
                _spotPrice: spotPrice,
                _initialNFTIDs: initialNftIds
            });
        } else {
            // For this pairing, we additionally need to transfer our ERC20 token
            ERC20 _token = ERC20(token);
            _token.transferFrom(msg.sender, address(this), initialTokenBalance);
            _token.approve(address(pairFactory), initialTokenBalance);

            // When we have an ERC20 defined, then we pair ERC20 <-> ERC721
            pair = pairFactory.createPairERC20(
                LSSVMPairFactory.CreateERC20PairParams({
                    token: _token,
                    nft: _nft,
                    bondingCurve: ICurve(bondingCurve),
                    assetRecipient: assetRecipient,
                    poolType: poolType,
                    delta: delta,
                    fee: fee,
                    spotPrice: spotPrice,
                    initialNFTIDs: initialNftIds,
                    initialTokenBalance: initialTokenBalance
                })
            );
        }

        // Transfer the ownership of the created pair to the caller
        pair.transferOwnership(msg.sender);

        // Return our integer address equivalent
        return uint(uint160(address(pair)));
    }
}
