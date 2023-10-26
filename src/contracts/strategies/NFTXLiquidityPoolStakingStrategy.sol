// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/interfaces/IERC1155.sol';

import {CannotDepositZeroAmount, CannotWithdrawZeroAmount, NoRewardsAvailableToClaim} from '@floor/utils/Errors.sol';

import {BaseStrategy, InsufficientPosition, ZeroAmountReceivedFromWithdraw} from '@floor/strategies/BaseStrategy.sol';

import {ITimelockRewardDistributionToken} from '@floor-interfaces/nftx/TimelockRewardDistributionToken.sol';
import {INFTXVault} from '@floor-interfaces/nftx/NFTXVault.sol';
import {INFTXLiquidityStaking} from '@floor-interfaces/nftx/NFTXLiquidityStaking.sol';
import {INFTXStakingZap} from '@floor-interfaces/nftx/NFTXStakingZap.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * Supports an Liquidity Staking position against a single NFTX vault. This strategy
 * will hold the corresponding xToken against deposits.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 *
 * @dev This contract does not support PUNK tokens. If a strategy needs to be established
 * then it should be done through another, bespoke contract.
 */
contract NFTXLiquidityPoolStakingStrategy is BaseStrategy {
    using SafeERC20 for IERC20;

    /// The NFTX vault ID that the strategy is attached to
    uint public vaultId;

    /// The underlying token will be the same as the address of the NFTX vault.
    address public underlyingToken;

    /// The yield token will be a vault xToken as defined by the LP contract.
    address public yieldToken;

    /// The reward token will be a vToken as defined by the LP contract.
    address public rewardToken;

    /// The ERC721 / ERC1155 token asset for the NFTX vault
    address public assetAddress;

    /// The NFTX zap addresses
    INFTXLiquidityStaking public liquidityStaking;
    INFTXStakingZap public stakingZap;

    /// Track the amount of deposit token
    uint public deposits;

    // Store our WETH reference
    IWETH public WETH;

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
            address _underlyingToken,
            address _yieldToken,
            address _rewardToken,
            address _liquidityStaking,
            address _stakingZap,
            address _weth
        ) = abi.decode(_initData, (uint, address, address, address, address, address, address));

        // Map our NFTX information
        vaultId = _vaultId;
        underlyingToken = _underlyingToken;
        yieldToken = _yieldToken;
        rewardToken = _rewardToken;
        stakingZap = INFTXStakingZap(_stakingZap);
        liquidityStaking = INFTXLiquidityStaking(_liquidityStaking);

        // Register our WETH contract address
        WETH = IWETH(_weth);

        // Set our ERC721 / ERC1155 token asset address
        assetAddress = INFTXVault(_rewardToken).assetAddress();

        // Set the underlying token as valid to process
        _validTokens[underlyingToken] = true;

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Deposit the underlying token into the LP staking pool.
     *
     * @return amount_ Amount of yield token returned from NFTX
     */
    function depositErc20(uint amount)
        external
        nonReentrant
        whenNotPaused
        updatesPosition(yieldToken)
        returns (uint amount_)
    {
        // Prevent users from trying to deposit nothing
        if (amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Capture our starting balance
        uint startXTokenBalance = IERC20(yieldToken).balanceOf(address(this));

        // Transfer the underlying token from our caller
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), amount);
        deposits += amount;

        // Approve the NFTX contract against our underlying token
        IERC20(underlyingToken).approve(address(liquidityStaking), amount);

        // Deposit the token into the NFTX contract
        liquidityStaking.deposit(vaultId, amount);

        // Determine the amount of yield token returned from our deposit
        amount_ = IERC20(yieldToken).balanceOf(address(this)) - startXTokenBalance;
    }

    function depositErc721(uint[] calldata tokenIds, uint minWethIn, uint wethIn)
        external
        nonReentrant
        whenNotPaused
        updatesPosition(yieldToken)
        refundsWeth
    {
        // Pull tokens in
        uint tokensLength = tokenIds.length;
        for (uint i; i < tokensLength;) {
            IERC721(assetAddress).transferFrom(msg.sender, address(this), tokenIds[i]);
            unchecked {
                ++i;
            }
        }

        // Pull our WETH from the sender
        WETH.transferFrom(msg.sender, address(this), wethIn);

        // Approve stakingZap and WETH allocation
        IERC721(assetAddress).setApprovalForAll(address(stakingZap), true);
        IERC20(WETH).approve(address(stakingZap), wethIn);

        // Push tokens out with WETH allocation
        stakingZap.addLiquidity721To(vaultId, tokenIds, minWethIn, wethIn, address(this));
    }

    function depositErc1155(uint[] calldata tokenIds, uint[] calldata amounts, uint minWethIn, uint wethIn)
        external
        nonReentrant
        whenNotPaused
        updatesPosition(yieldToken)
        refundsWeth
    {
        // Pull tokens in
        IERC1155(assetAddress).safeBatchTransferFrom(msg.sender, address(this), tokenIds, amounts, '');

        // Pull our WETH from the sender
        WETH.transferFrom(msg.sender, address(this), wethIn);

        // Approve stakingZap and WETH allocation
        IERC1155(assetAddress).setApprovalForAll(address(stakingZap), true);
        IERC20(WETH).approve(address(stakingZap), wethIn);

        // Push tokens out
        stakingZap.addLiquidity1155To(vaultId, tokenIds, amounts, minWethIn, wethIn, address(this));
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @dev Implements `nonReentrant` through `_withdrawErc20`
     *
     * @param amount Amount of yield token to withdraw
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdrawErc20(address recipient, uint amount) external onlyOwner returns (uint) {
        // Prevent users from trying to claim nothing
        if (amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        return _withdrawErc20(recipient, amount);
    }

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
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
        // Get the total amount of underlyingToken that has been deposited. From that, take
        // the percentage of the token.
        uint amount = (position[yieldToken] * percentage) / 100_00;

        tokens_ = validTokens();

        // Call our internal {withdrawErc20} function to move tokens to the caller
        amounts_ = new uint[](1);
        amounts_[0] = _withdrawErc20(recipient, amount);
    }

    function _withdrawErc20(address recipient, uint amount) internal nonReentrant returns (uint amount_) {
        // Ensure our user has sufficient position to withdraw from
        if (amount > position[yieldToken]) {
            revert InsufficientPosition(yieldToken, amount, position[yieldToken]);
        }

        // Capture our starting balance
        uint startTokenBalance = IERC20(underlyingToken).balanceOf(address(this));

        // Process our withdrawal against the NFTX contract
        liquidityStaking.withdraw(vaultId, amount);

        // Determine the amount of `underlyingToken` received
        amount_ = IERC20(underlyingToken).balanceOf(address(this)) - startTokenBalance;
        if (amount_ == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the received token to the caller
        IERC20(underlyingToken).safeTransfer(recipient, amount_);

        unchecked {
            deposits -= amount_;

            // We can now reduce the users position and total position held by the strategy
            position[yieldToken] -= amount;
        }

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(underlyingToken, amount_, recipient);
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view override returns (address[] memory tokens_, uint[] memory amounts_) {
        // Set up our return arrays
        tokens_ = new address[](1);
        amounts_ = new uint[](1);

        // Assign our yield token as the return
        tokens_[0] = yieldToken;

        // Get the xToken balance held by the strategy that is in addition to the amount
        // deposited. This should show only the gain / rewards generated.
        amounts_[0] = ITimelockRewardDistributionToken(yieldToken).dividendOf(address(this));
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action via the {StrategyFactory}.
     */
    function harvest(address _recipient) external override onlyOwner {
        (, uint[] memory amounts) = this.available();

        if (amounts[0] != 0) {
            // Withdraw our xToken to return vToken from the NFTX staking contract
            liquidityStaking.claimRewards(vaultId);

            // We can now withdraw all of the vToken from the contract
            IERC20(rewardToken).safeTransfer(_recipient, IERC20(rewardToken).balanceOf(address(this)));

            unchecked {
                lifetimeRewards[yieldToken] += amounts[0];
            }
        }

        emit Harvest(yieldToken, amounts[0]);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = underlyingToken;
        return tokens_;
    }

    /**
     * Increases our yield token position based on the logic transacted in the call.
     *
     * @dev This should be called for any deposit calls made.
     */
    modifier updatesPosition(address token) {
        // Capture our starting balance
        uint startBalance = IERC20(token).balanceOf(address(this));

        _;

        // Determine the amount of yield token returned from our deposit
        uint amount = IERC20(token).balanceOf(address(this)) - startBalance;

        // Increase the user's position and the total position for the strategy
        unchecked {
            position[token] += amount;
        }

        // Emit our event to followers
        emit Deposit(token, amount, msg.sender);
    }

    modifier refundsWeth() {
        // Capture our starting balance
        uint startBalance = WETH.balanceOf(address(this));

        _;

        // Determine the amount of remaining WETH token to be returned
        uint amount = WETH.balanceOf(address(this)) - startBalance;
        if (amount != 0) {
            WETH.transfer(msg.sender, amount);
        }
    }

    /**
     * Allows the contract to receive ERC1155 tokens.
     */
    function onERC1155Received(address, address, uint, uint, bytes calldata) public view returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');
        return this.onERC1155Received.selector;
    }

    /**
     * Allows the contract to receive batch ERC1155 tokens.
     */
    function onERC1155BatchReceived(address, address, uint[] calldata, uint[] calldata, bytes calldata) external view returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');
        return this.onERC1155BatchReceived.selector;
    }
}
