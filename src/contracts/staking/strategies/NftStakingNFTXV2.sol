// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {INFTXUnstakingInventoryZap} from '@floor-interfaces/nftx/NFTXUnstakingInventoryZap.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {INftStakingStrategy} from '@floor-interfaces/staking/strategies/NftStakingStrategy.sol';

/**
 * This contract allows approved collection NFTs to be depoited into it to generate
 * additional vote reward boosting through the calculation of a multiplier.
 */

contract NftStakingNFTXV2 is INftStakingStrategy, Ownable {
    /// Stores the equivalent ERC20 of the ERC721
    mapping(address => address) public underlyingTokenMapping;
    mapping(address => address) public underlyingXTokenMapping;

    /// Store a mapping of NFTX vault address to vault ID for gas savings
    mapping(address => uint) internal cachedNftxVaultId;

    /// Store our NFTX staking zaps
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /// Temp. user store for ERC721 receipt
    address private _nftReceiver;

    /// Allows NFTX references for when receiving rewards
    address internal inventoryStaking;
    address internal treasury;
    address internal immutable nftStaking;

    /// Keep track of the number of token deposits to calculate rewards available
    uint internal tokensStaked;

    /**
     * Sets up our immutable contract addresses.
     */
    constructor(address _nftStaking) {
        nftStaking = _nftStaking;
    }

    /**
     * Shows the address that should be approved by a staking user.
     *
     * @dev NFTX zap does not allow tokens to be sent from anyone other than caller.
     */
    function approvalAddress() external view returns (address) {
        return address(this);
    }

    /**
     * Stakes an approved collection NFT into the contract and provides a boost based on
     * the price of the underlying ERC20.
     *
     * @dev This can only be called when the contract is not paused.
     *
     * @param _user Address of the user staking their tokens
     * @param _collection Approved collection contract
     * @param _tokenId[] Token IDs to be staked
     * @param _amount[] The number of tokens to transfer
     * @param _is1155 If the collection is an ERC1155 standard
     */
    function stake(address _user, address _collection, uint[] calldata _tokenId, uint[] calldata _amount, bool _is1155)
        external
        onlyNftStaking
    {
        // If we have an 1155 collection, then we can use batch transfer
        if (_is1155) {
            IERC1155(_collection).safeBatchTransferFrom(_user, address(this), _tokenId, _amount, '');
        }

        uint length = _tokenId.length;
        for (uint i; i < length;) {
            if (!_is1155) {
                // A non-1155 should always have an amount of 1
                require(_amount[i] == 1);

                // Approve the staking zap to handle the collection tokens
                if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
                    IERC721(_collection).safeTransferFrom(_user, address(this), _tokenId[i], bytes(''));
                } else {
                    // Confirm that the PUNK belongs to the caller
                    bytes memory punkIndexToAddress = abi.encodeWithSignature('punkIndexToAddress(uint256)', _tokenId[i]);
                    (bool success, bytes memory result) = address(_collection).staticcall(punkIndexToAddress);
                    require(success && abi.decode(result, (address)) == _user, 'Not the NFT owner');

                    // Buy our PUNK for zero value
                    bytes memory data = abi.encodeWithSignature('buyPunk(uint256)', _tokenId[i]);
                    (success, result) = address(_collection).call(data);
                    require(success, string(result));

                    // Approve the staking zap to buy for zero value
                    data =
                        abi.encodeWithSignature('offerPunkForSaleToAddress(uint256,uint256,address)', _tokenId[i], 0, address(stakingZap));
                    (success, result) = address(_collection).call(data);
                    require(success, string(result));
                }
            }

            unchecked {
                // Increase our internal tally of staked tokens
                tokensStaked += _amount[i];
                ++i;
            }
        }

        // Approve all tokens for our collection. This increases gas for our first call,
        // but subsequent calls against the same token contract will save.
        // @dev This will work for both ERC721 and ERC1155.
        if (_collection != 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB) {
            if (!IERC721(_collection).isApprovedForAll(address(this), address(stakingZap))) {
                IERC721(_collection).setApprovalForAll(address(stakingZap), true);
            }
        }

        // Stake the token into NFTX vault. We have to vary the call logic depending on if
        // the collection is 721 or 1155 standard.
        if (_is1155) {
            stakingZap.provideInventory1155(_getVaultId(_collection), _tokenId, _amount);
        } else {
            stakingZap.provideInventory721(_getVaultId(_collection), _tokenId);
        }
    }

    /**
     * Unstakes an approved NFT from the contract and reduced the user's boost based on
     * the relevant metadata on the NFT.
     *
     * @param recipient The recipient of the unstaked NFT
     * @param _collection The collection to unstake
     * @param numNfts The number of NFTs to unstake for the recipient
     * @param baseNfts The number of NFTs that this unstaking represents
     * @param remainingPortionToUnstake The dust of NFT to unstake
     */
    function unstake(
        address recipient,
        address _collection,
        uint numNfts,
        uint baseNfts,
        uint remainingPortionToUnstake,
        bool /* _is1155 */
    ) external onlyNftStaking {
        // Set our NFT receiver so that our callback function can hook into the correct
        // recipient. We have to do this as NFTX doesn't allow a recipient to be specified
        // when calling the unstaking zap. This only needs to be done if we expect to
        // receive an NFT.
        if (numNfts != 0) {
            _nftReceiver = recipient;
        }

        // Approve the max usage of the underlying token against the unstaking zap
        IERC20(underlyingXTokenMapping[_collection]).approve(address(unstakingZap), type(uint).max);

        // Unstake all inventory for the user for the collection. This forked version of the
        // NFTX unstaking zap allows us to specify the recipient, so we don't need to handle
        // any additional transfers.
        unstakingZap.unstakeInventory(_getVaultId(_collection), numNfts, remainingPortionToUnstake);

        // Transfer our remaining portion to the user
        if (remainingPortionToUnstake != 0) {
            // Get our held underlying balance and then find the max between the two
            uint underlyingBalance = IERC20(underlyingTokenMapping[_collection]).balanceOf(address(this));
            if (underlyingBalance < remainingPortionToUnstake) {
                // We minus variable dust from the amount sent due to a small rounding
                // error in NFTX calculations.
                remainingPortionToUnstake = underlyingBalance;
            }

            IERC20(underlyingTokenMapping[_collection]).transfer(recipient, remainingPortionToUnstake - 2);
        }

        unchecked {
            tokensStaked -= baseNfts;
        }

        // After our NFTs have been unstaked, we want to make sure we delete the receiver
        delete _nftReceiver;
    }

    /**
     * Determines the amount of rewards available to be collected.
     */
    function rewardsAvailable(address _collection) external returns (uint) {
        // Get the corresponding vault ID of the collection
        uint vaultId = _getVaultId(_collection);

        // Get the amount of rewards avaialble to claim
        uint userTokens = tokensStaked * 1e18;

        // Get the xToken balance held by the strategy
        uint xTokenUserBal =
            IERC20(INFTXInventoryStaking(inventoryStaking).xTokenAddr(underlyingTokenMapping[_collection])).balanceOf(address(this));

        // Get the number of vTokens valued per xToken in wei
        uint shareValue = INFTXInventoryStaking(inventoryStaking).xTokenShareValue(vaultId);
        uint reqXTokens = (userTokens * 1e18) / shareValue;

        // If we require more xTokens than are held to allow our users to withdraw their
        // staked NFTs (NFTX dust issue) then we need to catch this and return zero.
        if (reqXTokens > xTokenUserBal) {
            return 0;
        }

        // Get the total rewards available above what would be required for a user
        // to mint their tokens back out of the vault.
        return xTokenUserBal - reqXTokens;
    }

    /**
     * Allows rewards to be claimed from the staked NFT inventory positions.
     */
    function claimRewards(address _collection) external returns (uint rewardsAvailable_) {
        // Get the corresponding vault ID of the collection
        uint vaultId = _getVaultId(_collection);

        // Get the amount of rewards available to be claimed
        rewardsAvailable_ = this.rewardsAvailable(_collection);

        // If we have rewards available, then we want to claim them from the vault and transfer it
        // into our {Treasury}.
        if (rewardsAvailable_ != 0) {
            INFTXInventoryStaking(inventoryStaking).withdraw(vaultId, rewardsAvailable_);
            IERC20(underlyingTokenMapping[_collection]).transfer(treasury, rewardsAvailable_);
        }
    }

    /**
     * Gets the underlying token for a collection.
     */
    function underlyingToken(address _collection) external view returns (address) {
        require(underlyingTokenMapping[_collection] != address(0), 'Unmapped collection');
        return underlyingTokenMapping[_collection];
    }

    /**
     * Sets the NFTX staking zaps that we will be interacting with.
     *
     * @param _stakingZap The {NFTXStakingZap} contract address
     * @param _unstakingZap The {NFTXUnstakingInventoryZap} contract address
     */
    function setStakingZaps(address _stakingZap, address _unstakingZap) external onlyOwner {
        require(_stakingZap != address(0));
        require(_unstakingZap != address(0));

        stakingZap = INFTXStakingZap(_stakingZap);
        unstakingZap = INFTXUnstakingInventoryZap(_unstakingZap);
    }

    /**
     * Allows us to set internal contracts that are used when claiming rewards.
     */
    function setContracts(address _inventoryStaking, address _treasury) external onlyOwner {
        inventoryStaking = _inventoryStaking;
        treasury = _treasury;
    }

    /**
     * Maps a collection address to an underlying NFTX token address. This will allow us to assign
     * a corresponding NFTX vault against our collection.
     *
     * @param _collection Our approved collection address
     * @param _token The underlying token (the NFTX vault contract address)
     */
    function setUnderlyingToken(address _collection, address _token, address _xToken) external onlyOwner {
        require(_collection != address(0));
        require(_token != address(0));

        // Map our collection to the underlying token
        underlyingTokenMapping[_collection] = _token;
        underlyingXTokenMapping[_collection] = _xToken;
    }

    /**
     * Calculates the NFTX vault ID of a collection address and then stores it to a local cache
     * as this value will not change.
     *
     * @param _collection The address of the collection being checked
     *
     * @return Numeric NFTX vault ID
     */
    function _getVaultId(address _collection) internal returns (uint) {
        // As we need to check a 0 value in our mapping to determine if it is not set, I have
        // hardcoded the vault collection that actually has a 0 ID to prevent any false positives.
        if (_collection == 0x269616D549D7e8Eaa82DFb17028d0B212D11232A) {
            return 0;
        }

        // If we have a cached mapping, then we can just return this directly
        if (cachedNftxVaultId[_collection] != 0) {
            return cachedNftxVaultId[_collection];
        }

        // Using the NFTX vault interface, reference the ERC20 which is also the vault address
        // to get the vault ID.
        return cachedNftxVaultId[_collection] = INFTXVault(underlyingTokenMapping[_collection]).vaultId();
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint tokenId, bytes memory) public virtual returns (bytes4) {
        if (_nftReceiver != address(0)) {
            IERC721(msg.sender).safeTransferFrom(address(this), _nftReceiver, tokenId);
        }
        return this.onERC721Received.selector;
    }

    /**
     * Allows the contract to receive ERC1155 tokens.
     */
    function onERC1155Received(address, address, uint tokenId, uint amount, bytes calldata) public virtual returns (bytes4) {
        if (_nftReceiver != address(0)) {
            IERC1155(msg.sender).safeTransferFrom(address(this), _nftReceiver, tokenId, amount, '');
        }
        return this.onERC1155Received.selector;
    }

    /**
     * Allows the contract to receive batch ERC1155 tokens.
     */
    function onERC1155BatchReceived(address, address, uint[] calldata tokenIds, uint[] calldata amounts, bytes calldata)
        public
        virtual
        returns (bytes4)
    {
        if (_nftReceiver != address(0)) {
            IERC1155(msg.sender).safeBatchTransferFrom(address(this), _nftReceiver, tokenIds, amounts, '');
        }
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * Ensures that only the {NftStaking} contract can call the function.
     */
    modifier onlyNftStaking() {
        require(msg.sender == nftStaking, 'Invalid caller');
        _;
    }
}
