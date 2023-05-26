// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '@floor/utils/Errors.sol';

import {BaseStrategy, InsufficientPosition, ZeroAmountReceivedFromWithdraw} from '@floor/strategies/BaseStrategy.sol';

import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXInventoryStaking} from '@floor-interfaces/nftx/NFTXInventoryStaking.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {INFTXUnstakingInventoryZap} from '@floor-interfaces/nftx/NFTXUnstakingInventoryZap.sol';

/**
 * Supports an Inventory Staking position against a single NFTX vault. This strategy
 * will hold the corresponding xToken against deposits.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 *
 * @dev This contract does not support PUNK tokens. If a strategy needs to be established
 * then it should be done through another, bespoke contract.
 *
 * https://etherscan.io/address/0x3E135c3E981fAe3383A5aE0d323860a34CfAB893#readProxyContract
 */
contract NFTXInventoryStakingStrategy is BaseStrategy {
    /// The NFTX vault ID that the strategy is attached to
    uint public vaultId;

    /// The underlying token will be the same as the address of the NFTX vault.
    address public underlyingToken;

    /// The reward yield will be a vault xToken as defined by the InventoryStaking contract.
    address public yieldToken;

    /// The ERC721 / ERC1155 token asset for the NFTX vault
    address public assetAddress;

    /// Address of the NFTX Inventory Staking contract
    INFTXInventoryStaking public inventoryStaking;

    /// The NFTX zap addresses
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /// Track the amount of deposit token
    uint private deposits;

    /// Stores the temporary recipient of any ERC721 and ERC1155 tokens that are received
    /// by the contract.
    address private _nftReceiver;

    /**
     * Sets up our contract variables.
     *
     * @param _name The name of the strategy
     * @param _strategyId ID index of the strategy created
     * @param _initData Encoded data to be decoded
     */
    function initialize(bytes32 _name, uint _strategyId, bytes calldata _initData) public initializer {
        // Set our vault name
        name = _name;

        // Set our strategy ID
        strategyId = _strategyId;

        // Extract the NFTX information from our initialisation bytes data
        (
            uint _vaultId,
            address _underlyingToken,
            address _yieldToken,
            address _inventoryStaking,
            address _stakingZap,
            address _unstakingZap
        ) = abi.decode(_initData, (uint, address, address, address, address, address));

        // Map our NFTX information
        vaultId = _vaultId;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        stakingZap = INFTXStakingZap(_stakingZap);
        unstakingZap = INFTXUnstakingInventoryZap(_unstakingZap);
        inventoryStaking = INFTXInventoryStaking(_inventoryStaking);

        // Set our ERC721 / ERC1155 token asset address
        assetAddress = INFTXVault(_underlyingToken).assetAddress();

        // Set the underlying token as valid to process
        _validTokens[underlyingToken] = true;

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Deposit underlying token or yield token to corresponding strategy.
     *
     * Requirements:
     *  - Caller should make sure the token is already transfered into the strategy contract.
     *  - Caller should make sure the deposit amount is greater than zero.
     *
     * - Get the vault ID from the underlying address (vault address)
     * - InventoryStaking.deposit(uint256 vaultId, uint256 _amount)
     *   - This deposit will be timelocked
     * - We receive xToken back to the strategy
     *
     * @return amount_ Amount of yield token returned from NFTX
     */
    function depositErc20(uint amount) external nonReentrant whenNotPaused returns (uint amount_) {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Capture our starting balance
        uint startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));

        // Transfer the underlying token from our caller
        IERC20(underlyingToken).transferFrom(msg.sender, address(this), amount);
        deposits += amount;

        // Approve the NFTX contract against our underlying token
        IERC20(underlyingToken).approve(address(inventoryStaking), amount);

        // Deposit the token into the NFTX contract
        inventoryStaking.deposit(vaultId, amount);

        // Determine the amount of yield token returned from our deposit
        amount_ = IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;

        // Increase the user's position and the total position for the vault
        unchecked {
            position[yieldToken] += amount_;
        }

        // Emit our event to followers
        emit Deposit(underlyingToken, amount, amount_, msg.sender);
    }

    function depositErc721(uint[] calldata tokenIds) external {
        // Pull tokens in
        uint tokensLength = tokenIds.length;
        for (uint i; i < tokensLength;) {
            IERC721(assetAddress).transferFrom(msg.sender, address(this), tokenIds[i]);
            unchecked {
                ++i;
            }
        }

        // Approve stakingZap
        IERC721(assetAddress).setApprovalForAll(address(stakingZap), true);

        // Push tokens out
        stakingZap.provideInventory721(vaultId, tokenIds);
    }

    function depositErc1155(uint[] calldata tokenIds, uint[] calldata amounts) external {
        // Pull tokens in
        IERC1155(assetAddress).safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, '');

        // Approve stakingZap
        IERC1155(assetAddress).setApprovalForAll(address(stakingZap), true);

        // Push tokens out
        stakingZap.provideInventory1155(vaultId, tokenIds, amounts);
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @param amount Amount of yield token to withdraw
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdrawErc20(address recipient, uint amount) external nonReentrant onlyOwner returns (uint amount_) {
        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        // Ensure our user has sufficient position to withdraw from
        if (amount > position[yieldToken]) {
            revert InsufficientPosition(yieldToken, amount, position[yieldToken]);
        }

        // Capture our starting balance
        uint startTokenBalance = IERC20(underlyingToken).balanceOf(address(this));

        // Process our withdrawal against the NFTX contract
        inventoryStaking.withdraw(vaultId, amount);

        // Determine the amount of `underlyingToken` received
        amount_ = IERC20(underlyingToken).balanceOf(address(this)) - startTokenBalance;
        if (amount_ == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the received token to the caller
        IERC20(underlyingToken).transfer(recipient, amount_);

        unchecked {
            deposits -= amount_;

            // We can now reduce the users position and total position held by the vault
            position[yieldToken] -= amount;
        }

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(underlyingToken, amount_, recipient);
    }

    function withdrawErc721(address _recipient, uint _numNfts, uint _partial) external nonReentrant onlyOwner {
        _unstakeInventory(_recipient, _numNfts, _partial);
    }

    function withdrawErc1155(address _recipient, uint _numNfts, uint _partial) external nonReentrant onlyOwner {
        _unstakeInventory(_recipient, _numNfts, _partial);
    }

    function _unstakeInventory(address _recipient, uint _numNfts, uint _partial) internal {
        // Before we can withdraw, we need to allow the contract to manage our ERC20
        IERC20(yieldToken).approve(address(unstakingZap), type(uint).max);

        // Set our NFT receiver so that our safe transfer will pass it on
        _nftReceiver = _recipient;

        // Unstake our ERC721's and partial remaining tokens
        unstakingZap.unstakeInventory(vaultId, _numNfts, _partial);

        // Delete our NFT receiver to prevent unexpected transactions
        delete _nftReceiver;

        // If we have requested `_partial` token to be returned, then we need to send
        // this over.
        if (_partial > 0) {
            IERC20(underlyingToken).transfer(_recipient, _partial - 1);
        }
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external view override returns (address[] memory tokens_, uint[] memory amounts_) {
        // Set up our return arrays
        tokens_ = new address[](1);
        amounts_ = new uint[](1);

        // Assign our yield token as the return
        tokens_[0] = yieldToken;

        // Get the xToken balance held by the strategy that is in addition to the amount
        // deposited. This should show only the gain / rewards generated.
        amounts_[0] = IERC20(yieldToken).balanceOf(address(this)) - position[yieldToken];
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action via the {StrategyFactory}.
     */
    function harvest(address _recipient) external override onlyOwner {
        (, uint[] memory amounts) = this.available();

        if (amounts[0] != 0) {
            // Withdraw our xToken to return vToken from the NFTX inventory staking contract
            inventoryStaking.withdraw(vaultId, amounts[0]);

            // We can now withdraw all of the vToken from the contract
            IERC20(underlyingToken).transfer(_recipient, IERC20(underlyingToken).balanceOf(address(this)));

            unchecked {
                lifetimeRewards[yieldToken] += amounts[0];
            }
        }

        emit Harvest(yieldToken, amounts[0]);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view override returns (address[] memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = underlyingToken;
        return tokens_;
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, /* _from */ address, /* _to */ uint _id, bytes memory /* _data */ ) public returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');

        if (_nftReceiver != address(0)) {
            IERC721(assetAddress).safeTransferFrom(address(this), _nftReceiver, _id);
        }

        return this.onERC721Received.selector;
    }

    /**
     * Allows the contract to receive ERC1155 tokens.
     */
    function onERC1155Received(address, /* _from */ address, /* _to */ uint _id, uint _value, bytes calldata _data)
        public
        returns (bytes4)
    {
        require(msg.sender == assetAddress, 'Invalid asset');

        if (_nftReceiver != address(0)) {
            IERC1155(assetAddress).safeTransferFrom(address(this), _nftReceiver, _id, _value, _data);
        }

        return this.onERC1155Received.selector;
    }

    /**
     * Allows the contract to receive batch ERC1155 tokens.
     */
    function onERC1155BatchReceived(
        address, /* _from */
        address, /* _to */
        uint[] calldata _ids,
        uint[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');

        if (_nftReceiver != address(0)) {
            IERC1155(assetAddress).safeBatchTransferFrom(address(this), _nftReceiver, _ids, _values, _data);
        }

        return this.onERC1155BatchReceived.selector;
    }
}
