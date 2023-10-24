// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
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
    using SafeERC20 for IERC20;

    /// The NFTX vault ID that the strategy is attached to
    uint public vaultId;

    /// The underlying token will be the same as the address of the NFTX vault.
    IERC20 public vToken;

    /// The reward yield will be a vault xToken as defined by the InventoryStaking contract.
    IERC20 public xToken;

    /// The ERC721 / ERC1155 token asset for the NFTX vault
    address public assetAddress;

    /// Address of the NFTX Inventory Staking contract
    INFTXInventoryStaking public inventoryStaking;

    /// The NFTX zap addresses
    INFTXStakingZap public stakingZap;
    INFTXUnstakingInventoryZap public unstakingZap;

    /// Track the amount of deposit token, which in this instance will be recorded
    /// as the received xToken, and not the initial vToken.
    uint public deposits;

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
        // Set our strategy name
        name = _name;

        // Set our strategy ID
        strategyId = _strategyId;

        // Extract the NFTX information from our initialisation bytes data
        (
            uint _vaultId,
            address _vToken,
            address _xToken,
            address _inventoryStaking,
            address _stakingZap,
            address _unstakingZap
        ) = abi.decode(_initData, (uint, address, address, address, address, address));

        // Map our NFTX information
        vaultId = _vaultId;
        vToken = IERC20(_vToken);
        xToken = IERC20(_xToken);
        stakingZap = INFTXStakingZap(_stakingZap);
        unstakingZap = INFTXUnstakingInventoryZap(_unstakingZap);
        inventoryStaking = INFTXInventoryStaking(_inventoryStaking);

        // Set our ERC721 / ERC1155 token asset address
        assetAddress = INFTXVault(_vToken).assetAddress();

        // Set the underlying token as valid to process
        _validTokens[_vToken] = true;

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
     */
    function depositErc20(uint amount) external nonReentrant whenNotPaused {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Transfer the underlying token from our caller
        vToken.safeTransferFrom(msg.sender, address(this), amount);

        // Approve the NFTX contract against our underlying token
        vToken.approve(address(inventoryStaking), amount);

        // Deposit the token into the NFTX contract
        inventoryStaking.deposit(vaultId, amount);

        // Increase the user's position and the total position for the strategy
        deposits += amount;
        emit Deposit(address(vToken), amount, msg.sender);
    }

    function depositErc721(uint[] calldata tokenIds) external nonReentrant whenNotPaused {
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

        // Increase the user's position and the total position for the strategy
        deposits += (tokensLength * 1 ether);
        emit Deposit(address(vToken), (tokensLength * 1 ether), msg.sender);
    }

    function depositErc1155(uint[] calldata tokenIds, uint[] calldata amounts) external nonReentrant whenNotPaused {
        // Pull tokens in
        IERC1155(assetAddress).safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, '');

        // Approve stakingZap
        IERC1155(assetAddress).setApprovalForAll(address(stakingZap), true);

        // Push tokens out
        stakingZap.provideInventory1155(vaultId, tokenIds, amounts);

        // Increase the user's position and the total position for the strategy
        uint newDeposits;
        for (uint i; i < tokenIds.length;) {
            newDeposits += amounts[i];
            unchecked { ++i; }
        }

        deposits += (newDeposits * 1 ether);
        emit Deposit(address(vToken), (newDeposits * 1 ether), msg.sender);
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @dev Implements `nonReentrant` through `_withdrawErc20`
     *
     * @param amount Amount of yield token to withdraw defined in vToken
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdrawErc20(address recipient, uint amount) external onlyOwner returns (uint amount_) {
        // Ensure our user has sufficient xToken balance to withdraw from
        if (amount > deposits) {
            revert InsufficientPosition(address(vToken), amount, deposits);
        }

        return _withdrawErc20(recipient, amount);
    }

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
     *
     * @dev Implements `nonReentrant` through `_withdrawErc20`
     *
     * @param recipient Recipient of the withdrawal
     * @param percentage The 2 decimal accuracy of the percentage to withdraw (e.g. 100% = 10000)
     */
    function withdrawPercentage(address recipient, uint percentage)
        external
        override
        onlyOwner
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // Get the total amount of xToken held by the strategy. From this we can reference
        // the amount of vToken that is held.
        uint amount = (deposits * percentage) / 100_00;

        // Set up our return arrays
        tokens_ = new address[](1);
        tokens_[0] = address(vToken);

        // Call our internal {withdrawErc20} function to move tokens to the caller
        amounts_ = new uint[](1);
        amounts_[0] = _withdrawErc20(recipient, amount);
    }

    function _withdrawErc20(address recipient, uint amount) internal nonReentrant returns (uint amount_) {
        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        // Convert the requested amount of vToken to xToken using the share value calculation
        uint xTokenEquivalent = amount * 1 ether / inventoryStaking.xTokenShareValue(vaultId);

        // Capture our starting vToken balance
        uint startTokenBalance = vToken.balanceOf(address(this));

        // Process our withdrawal against the NFTX contract to receive vToken into the strategy
        inventoryStaking.withdraw(vaultId, xTokenEquivalent);

        // Determine the amount of `vToken` received and raise an exception if we gain
        // no vToken in return.
        amount_ = vToken.balanceOf(address(this)) - startTokenBalance;
        if (amount_ == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the received token to the recipient
        vToken.safeTransfer(recipient, amount_);

        // Update our deposit amount based on the amount of vToken withdrawn
        deposits -= amount_;

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(address(vToken), amount_, recipient);
    }

    /**
     * Withdraws an ERC721 token from the Inventory position. This will be pseudo-random.
     *
     * @dev Implements `nonReentrant` through `_unstakeInventory`
     */
    function withdrawErc721(address _recipient, uint _numNfts, uint _partial) external onlyOwner {
        _unstakeInventory(_recipient, _numNfts, _partial);
    }

    /**
     * Withdraws an ERC1155 token from the Inventory position. This will be pseudo-random.
     *
     * @dev Implements `nonReentrant` through `_unstakeInventory`
     */
    function withdrawErc1155(address _recipient, uint _numNfts, uint _partial) external onlyOwner {
        _unstakeInventory(_recipient, _numNfts, _partial);
    }

    function _unstakeInventory(address _recipient, uint _numNfts, uint _partial) internal nonReentrant {
        // Before we can withdraw, we need to allow the contract to manage our ERC20
        xToken.approve(address(unstakingZap), type(uint).max);

        // Set our NFT receiver so that our safe transfer will pass it on
        _nftReceiver = _recipient;

        // Get the start balance of the expected _partial token to receive if requested
        uint startTokenBalance = vToken.balanceOf(address(this));

        // Unstake our ERC721's and partial remaining tokens
        unstakingZap.unstakeInventory(vaultId, _numNfts, _partial);

        // Delete our NFT receiver to prevent unexpected transactions
        delete _nftReceiver;

        // Find the new balance of the tokens that we are withdrawing
        uint tokenDifference = vToken.balanceOf(address(this)) - startTokenBalance;

        // Ensure that we aren't withdrawing more than deposited
        if (tokenDifference > deposits) {
            revert InsufficientPosition(address(vToken), tokenDifference, deposits);
        }

        // Send the acquired vTokens to our recipient, and the inventory tokens will have
        // already been sent via the safe transfer.
        if (tokenDifference != 0) {
            vToken.safeTransfer(_recipient, tokenDifference);
        }

        // We can now reduce the users position and total position held by the strategy
        deposits -= tokenDifference;

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(address(vToken), tokenDifference, _recipient);
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() external view override returns (address[] memory tokens_, uint[] memory amounts_) {
        // Set up our return arrays
        tokens_ = new address[](1);
        amounts_ = new uint[](1);

        // Assign our vtoken as the token to claim
        tokens_[0] = address(vToken);

        // Get the xToken balance held by the strategy and find the share of vToken that this
        // is equivalent to. By removing the deposits from this, it should show only the rewards
        // generated. We also check underflow as may have dust missing after a deposit.
        uint vTokenEquivalent = (xToken.balanceOf(address(this)) * inventoryStaking.xTokenShareValue(vaultId)) / 1 ether;
        amounts_[0] = (vTokenEquivalent < deposits) ? 0 : vTokenEquivalent - deposits;
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action via the {StrategyFactory}.
     */
    function harvest(address _recipient) external override onlyOwner {
        (, uint[] memory amounts) = this.available();

        if (amounts[0] != 0) {
            // Withdraw our xToken to return vToken from the NFTX inventory staking contract
            inventoryStaking.withdraw(vaultId, (amounts[0] * 1 ether) / inventoryStaking.xTokenShareValue(vaultId));

            // We can now withdraw all of the vToken from the contract
            vToken.safeTransfer(_recipient, vToken.balanceOf(address(this)));

            unchecked {
                lifetimeRewards[address(vToken)] += amounts[0];
            }
        }

        emit Harvest(address(vToken), amounts[0]);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() external view override returns (address[] memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(vToken);
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
