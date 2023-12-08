// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/interfaces/IERC721.sol';

import {INFTXInventoryStakingV3} from '@nftx-protocol-v3/interfaces/INFTXInventoryStakingV3.sol';
import {INFTXVaultV3} from '@nftx-protocol-v3/interfaces/INFTXVaultV3.sol';

import {BaseStrategy, InsufficientPosition, ZeroAmountReceivedFromWithdraw} from '@floor/strategies/BaseStrategy.sol';
import {CannotDepositZeroAmount, CannotWithdrawZeroAmount} from '@floor/utils/Errors.sol';

import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';


/**
 * Supports an Liquidity Staking position against a single NFTX vault. This strategy
 * will hold the position ERC721 with corresponding xToken against deposits.
 *
 * The contract will extend the {BaseStrategy} to ensure it conforms to the required
 * logic and functionality. Only functions that have varied internal logic have been
 * included in this interface with function documentation to explain.
 */
contract NFTXV3Strategy is BaseStrategy {
    using SafeERC20 for IERC20;

    /// The NFTX V3 Inventory Staking zap addresses
    INFTXInventoryStakingV3 public staking;

    /// We need to store a number of position IDs as we don't want to wait
    /// for timelocks to pass. We cannot merge our positions, as this requires
    /// that there are no timelocks remaining on any of the positions.
    uint public parentPositionId;
    uint[] private _positionIds;

    /// Maintains a mapping of pending position IDs to confirm which are already
    /// present in the `_positionIds` array. This saves a small amount of gas when
    /// processing checks.
    mapping (uint => bool) private _pendingPositionIds;

    /// Stores the NFTX V3 Vault ID to query against
    uint public vaultId;

    /// Holds the vToken that is expected by the deposit
    IERC20 public vToken;

    /// Holds the token (WETH) that is earned as rewards
    IWETH public xToken;

    /// The address of the equivalent ERC721 / ERC1155
    address public assetAddress;

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
        address _staking;
        (vaultId, _staking) = abi.decode(_initData, (uint, address));

        // Set our {INFTXInventoryStakingV3} contract
        staking = INFTXInventoryStakingV3(_staking);

        INFTXVaultV3 _vault = INFTXVaultV3(staking.nftxVaultFactory().vault(vaultId));

        // Extract our vToken and vTokenShare address from the vault
        vToken = IERC20(address(_vault));
        xToken = IWETH(address(staking.WETH()));

        // Extract our asset address from the vault
        assetAddress = _vault.assetAddress();

        // Set the underlying token as valid to process
        _validTokens[address(_vault)] = true;

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);

        // Approve all tokens from the asset address to prevent future requirement. This
        // will be the same function call for both 721 and 1155.
        IERC721(assetAddress).setApprovalForAll(address(staking), true);
    }

    /**
     * Deposit the underlying token into the Inventory Staking pool.
     *
     * @return amount_ Amount of dividend token returned from NFTX
     */
    function depositErc20(uint _amount)
        external
        nonReentrant
        whenNotPaused
        mergePositions
        returns (uint amount_)
    {
        // Prevent users from trying to deposit nothing
        if (_amount == 0) {
            revert CannotDepositZeroAmount();
        }

        // Capture our starting balance to determine any possible refunds
        (,,,,, uint startVTokenShare,,) = staking.positions(parentPositionId);

        // Transfer the underlying token from our caller
        vToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Approve the NFTX contract against our underlying token
        vToken.approve(address(staking), _amount);

        // If we have a parent position already, then we want to increase the
        // current position, rather than creating a new one that would need to
        // be merged later.
        if (parentPositionId != 0) {
            staking.increasePosition(parentPositionId, _amount, '', false, false);
        }
        // If we don't have a parent position Id yet, then we need to create a
        // new position by calling the `deposit` function instead.
        else {
            // Generate and register our position ID
            _setPositionId(
                staking.deposit(vaultId, _amount, address(this), '', false, false)
            );
        }

        unchecked {
            // Determine the amount of vTokenShare returned from our deposit. This should
            // always query our parent token ID, as if it already exists then we will have
            // called the `increasePosition` function.
            (,,,,, uint closingVTokenShare,,) = staking.positions(parentPositionId);
            amount_ = closingVTokenShare - startVTokenShare;

            // Increase the user's position and the total position for the strategy
            position[address(vToken)] += amount_;
        }

        // Emit our event to followers
        emit Deposit(address(vToken), amount_, msg.sender);
    }

    /**
     * Pulls NFTs from sender, mints, and stakes vToken, and returns an xNFT inventory staking position.
     * The xNFT position will have a 3-day timelock, during which time an early withdrawal penalty is
     * charged in vToken if the owner of the position decides to withdraw. The early withdrawal penalty
     * is 10% of the position and goes down linearly to zero over the duration of the timelock.
     *
     * If the deposit is the first deposit that the inventory staking pool has ever received, then
     * MINIMUM_LIQUIDITY (i.e, 1000 wei) of the vTokenShares are locked up forever to prevent
     * front-running attacks.
     */
    function depositNfts(uint[] calldata _tokenIds, uint[] calldata _amounts)
        external
        nonReentrant
        whenNotPaused
        mergePositions
        returns (uint amount_)
    {
        // Pull tokens in from the sender
        uint tokensLength = _tokenIds.length;
        for (uint i; i < tokensLength;) {
            IERC721(assetAddress).transferFrom(msg.sender, address(this), _tokenIds[i]);
            unchecked { ++i; }
        }

        // Capture our starting balance. If we don't yet have a parent position ID, then this
        // will just return 0, which is correct
        (,,,,, uint startVTokenShare,,) = staking.positions(parentPositionId);

        // Generate and register our position ID
        _setPositionId(
            staking.depositWithNFT(vaultId, _tokenIds, _amounts, address(this))
        );

        unchecked {
            // Determine the amount of vTokenShare returned from our deposit. This should
            // always query our parent token ID, as if it already exists then we will have
            // called the `increasePosition` function.
            (,,,,, uint closingVTokenShare,,) = staking.positions(parentPositionId);
            amount_ = closingVTokenShare - startVTokenShare;

            // Increase the user's position and the total position for the strategy
            position[address(vToken)] += amount_;
        }

        // Emit our event to followers
        emit Deposit(address(vToken), amount_, msg.sender);
    }

    /**
     * Withdraws an amount of our position from the NFTX strategy.
     *
     * @dev Implements `nonReentrant` through `_withdrawErc20`
     *
     * @param _amount Amount of dividend token to withdraw
     *
     * @return amount_ Amount of the underlying token returned
     */
    function withdrawErc20(address _recipient, uint _amount) external onlyOwner mergePositions returns (uint) {
        // Prevent users from trying to claim nothing
        if (_amount == 0) {
            revert CannotWithdrawZeroAmount();
        }

        return _withdrawErc20(_recipient, _amount);
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
        mergePositions
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // Get the total amount of underlyingToken that has been deposited. From that, take
        // the percentage of the token.
        uint amount = (position[address(vToken)] * percentage) / 100_00;

        tokens_ = validTokens();

        // Call our internal {withdrawErc20} function to move tokens to the caller
        amounts_ = new uint[](1);
        amounts_[0] = _withdrawErc20(recipient, amount);
    }

    function _withdrawErc20(address recipient, uint amount) internal nonReentrant returns (uint amount_) {
        // We need to frontrun the withdrawal to harvest rewards, as the `withdraw` function
        // will collect during the process without us having knowledge of it otherwise.
        harvest(IStrategyFactory(owner()).treasury());

        // Ensure our user has sufficient position to withdraw from
        uint vTokenPosition = position[address(vToken)];
        if (amount > vTokenPosition) {
            revert InsufficientPosition(address(vToken), amount, vTokenPosition);
        }

        // Capture our starting balance
        uint startTokenBalance = vToken.balanceOf(address(this));

        // We set `vTokenPremiumLimit` to be 0, as we expect to be excluded from fees
        staking.withdraw(parentPositionId, amount, new uint[](0), amount);

        // Determine the amount of `underlyingToken` received
        amount_ = vToken.balanceOf(address(this)) - startTokenBalance;
        if (amount_ == 0) {
            revert ZeroAmountReceivedFromWithdraw();
        }

        // Transfer the received token to the caller
        vToken.safeTransfer(recipient, amount_);

        unchecked {
            // We can now reduce the users position and total position held by the strategy
            position[address(vToken)] -= amount;
        }

        // Fire an event to show amount of token claimed and the recipient
        emit Withdraw(address(vToken), amount_, recipient);
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view override returns (address[] memory tokens_, uint[] memory amounts_) {
        // Set up our return arrays
        tokens_ = new address[](1);
        amounts_ = new uint[](1);

        // Assign our dividend token as the return
        tokens_[0] = address(xToken);

        // Get the available weth balance from our parent position
        amounts_[0] = staking.wethBalance(parentPositionId);
    }

    /**
     * Extracts all rewards from third party and moves it to a recipient. This should
     * only be called by a specific action via the {StrategyFactory}.
     */
    function harvest(address _recipient) public override onlyOwner {
        // Collect WETH fees from our parent position
        uint[] memory parentPositionIdArray = new uint[](1);
        parentPositionIdArray[0] = parentPositionId;
        staking.collectWethFees(parentPositionIdArray);

        // We want to transfer all WETH (xToken) in the contract as rewards, so we don't
        // look to calculate change from the collection, but instead just the resulting
        // balance.
        uint balance = xToken.balanceOf(address(this));
        if (balance != 0) {
            bool result = xToken.transfer(_recipient, balance);
            require(result == true, 'Could not send WETH to recipient');

            unchecked {
                lifetimeRewards[address(xToken)] += balance;
            }
        }

        emit Harvest(address(xToken), balance);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(vToken);
        return tokens_;
    }

    /**
     * Returns an array of all child position IDs held by the strategy.
     */
    function positionIds() public view returns (uint[] memory) {
        return _positionIds;
    }

    /**
     * Helper function to show if the specified position ID is currently timelocked. This
     * means that withdrawals cannot be made against the position.
     */
    function isPositionTimelocked(uint positionId) public view returns (bool) {
        (,, uint timelockedUntil,, uint vTokenTimelockedUntil,,,) = staking.positions(positionId);
        return (block.timestamp <= timelockedUntil || block.timestamp <= vTokenTimelockedUntil);
    }

    /**
     * When a position ID is created and registered for the strategy, this function should
     * be called to either set it as the main, parent position ID that will be retained as
     * the main ERC721 that others are merged into.
     */
    function _setPositionId(uint positionId) private {
        // If there is no current parent position ID, then we set this as the parent
        if (parentPositionId == 0) {
            parentPositionId = positionId;
            return;
        }

        // We need to see if it's already a timelocked child and, if not, add to array
        // of children.
        if (!_pendingPositionIds[positionId]) {
            _positionIds.push(positionId);
            _pendingPositionIds[positionId] = true;
        }
    }

    /**
     * Merges child positions that has passed their timelock into our parent position.
     */
    modifier mergePositions() {
        uint positionIdsLength = _positionIds.length;

        // To process this modifier we need to have a parent position and
        // at least one child.
        if (parentPositionId == 0 || positionIdsLength == 0) {
            _;
            return;
        }

        // We cannot process any combinations if our parent is timelocked
        if (isPositionTimelocked(parentPositionId)) {
            _;
            return;
        }

        // Loop through our position IDs to check their expiry
        uint positionId;
        for (uint i; i < positionIdsLength;) {
            // Store our positionId as we may reference multiple times
            positionId = _positionIds[i];

            // If the position has not expired, then we continue parsing our array
            if (isPositionTimelocked(positionId)) {
                unchecked { ++i; }
                continue;
            }

            // If the position is unlocked, then we can combine it into our parent
            uint[] memory childPositionId = new uint[](1);
            childPositionId[0] = positionId;
            staking.combinePositions(parentPositionId, childPositionId);

            // Delete the position that has been combined
            delete _pendingPositionIds[positionId];
            _positionIds[i] = _positionIds[positionIdsLength - 1];
            _positionIds.pop();
            --positionIdsLength;
        }

        _;
    }

    /**
     * Allows the contract to receive ERC721 tokens.
     */
    function onERC721Received(address, address, uint, bytes calldata) public view returns (bytes4) {
        require(msg.sender == assetAddress, 'Invalid asset');
        return this.onERC721Received.selector;
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

    /**
     * Allows the contract to receive ETH into the contract and then convert it into
     * WETH which is claimed in our next harvest.
     */
    receive() external payable {
        xToken.deposit{value: msg.value}();
    }
}
