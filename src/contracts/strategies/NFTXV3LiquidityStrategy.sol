// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import {INFTXRouter} from '@nftx-protocol-v3/interfaces/INFTXRouter.sol';
import {INFTXVaultV3} from '@nftx-protocol-v3/interfaces/INFTXVaultV3.sol';

import {IUniswapV3Factory} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3Pool} from '@uniswap-v3/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {FixedPoint128} from '@uniswap-v3/v3-core/contracts/libraries/FixedPoint128.sol';
import {FullMath} from '@uniswap-v3/v3-core/contracts/libraries/FullMath.sol';
import {LiquidityAmounts} from '@uniswap-v3/v3-periphery/contracts/libraries/LiquidityAmounts.sol';
import {TickMath} from '@uniswap-v3/v3-core/contracts/libraries/TickMath.sol';

import {INonfungiblePositionManager} from '@uni-periphery/interfaces/INonfungiblePositionManager.sol';

import {BaseStrategy} from '@floor/strategies/BaseStrategy.sol';
import {CannotDepositZeroAmount} from '@floor/utils/Errors.sol';

import {IStrategyFactory} from '@floor-interfaces/strategies/StrategyFactory.sol';
import {IWETH} from '@floor-interfaces/tokens/WETH.sol';

/**
 * Interface that allows for both ERC721 and ERC1155 to call `setApprovalForAll`.
 */
interface ApprovalToken {
    function setApprovalForAll(address, bool) external;
}

/**
 * Sets up a strategy that interacts with NFTXV3 to create and manage liquidity positions.
 */
contract NFTXV3LiquidityStrategy is BaseStrategy {

    /// Our position ID that will be minted when we add liquidity
    uint public positionId;

    /// Store our NFTX vault
    uint public vaultId;
    INFTXVaultV3 public vault;

    /// Store our pool information
    uint24 public fee;
    uint96 public sqrtPriceX96;
    int24 public tickLower;
    int24 public tickUpper;

    /// Store our NFTX V3 vToken
    IERC20 public vToken;

    /// Store our WETH token
    IWETH public weth;

    /// Store our Uniswap pool address
    address public pool;

    /// Stores our NFTX router and {PositionManager}
    INFTXRouter public router;
    INonfungiblePositionManager public positionManager;

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

        // Extract information from our initialisation bytes data
        address _router;
        (vaultId, _router, fee, sqrtPriceX96, tickLower, tickUpper) = abi.decode(_initData, (uint, address, uint24, uint96, int24, int24));

        // Cast our position manager to an interface
        router = INFTXRouter(_router);
        positionManager = router.positionManager();
        vault = INFTXVaultV3(router.nftxVaultFactory().vault(vaultId));

        // Extract our vToken and vTokenShare address from the vault
        vToken = IERC20(address(vault));
        weth = IWETH(address(router.WETH()));

        // Get our deterministic pool address. It doesn't matter if this pool currently exists.
        pool = router.computePool(address(vault), fee);

        // Max approve our tokens
        vToken.approve(address(router), type(uint).max);

        // We can also approve our NFTs to be used by the router if we choose
        ApprovalToken(vault.assetAddress()).setApprovalForAll(address(router), true);
        positionManager.setApprovalForAll(address(router), true);

        // Transfer ownership to the caller
        _transferOwnership(msg.sender);
    }

    /**
     * Adds liquidity against an existing Uniswap ERC721 position.
     */
    function deposit(
        uint vTokenDesired,
        uint[] memory nftIds,
        uint[] memory nftAmounts,
        uint vTokenMin,
        uint wethMin,
        uint deadline
    )
        external
        payable
        nonReentrant
        returns (uint amount0, uint amount1)
    {
        // Ensure we have sent enough (w)ETH
        require(msg.value >= wethMin, 'Insufficient ETH');

        // Store the number of NFT IDs being depositted
        uint nftIdsLength = nftIds.length;

        // Check that we aren't trying to deposit nothing
        if (nftIdsLength + vTokenDesired + msg.value == 0) {
            revert CannotDepositZeroAmount();
        }

        // Pull tokens into the contract that are requested
        uint vTokenStartBalance = vToken.balanceOf(address(this));
        uint ethStartBalance = payable(address(this)).balance - msg.value;

        // Pull in the amount of vToken we are looking to use
        if (vTokenDesired != 0) {
            vToken.transferFrom(msg.sender, address(this), vTokenDesired);
        }

        // Pull in any NFTs that we have requested to deposit
        if (nftIdsLength != 0) {
            IERC721 asset = IERC721(vault.assetAddress());
            for (uint i; i < nftIdsLength;) {
                asset.transferFrom(msg.sender, address(this), nftIds[i]);
                unchecked { ++i; }
            }
        }

        // If we don't currently have a token ID for this strategy, then we need to mint one
        // when we first add liquidity.
        if (positionId == 0) {
            // Create our ERC721 and fund it with an initial desired amount of each token. We
            // capture the position ID that is created as we will refer to this moving forward.
            positionId = router.addLiquidity{value: msg.value}(
                INFTXRouter.AddLiquidityParams({
                    vaultId: vaultId,
                    vTokensAmount: vTokenDesired,
                    nftIds: nftIds,
                    nftAmounts: nftAmounts,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    fee: fee,
                    sqrtPriceX96: sqrtPriceX96,
                    vTokenMin: vTokenMin,
                    wethMin: wethMin,
                    deadline: deadline,
                    forceTimelock: false,
                    recipient: address(this)
                })
            );
        } else {
            // Increase our liquidity position
            router.increaseLiquidity{value: msg.value}(
                INFTXRouter.IncreaseLiquidityParams({
                    positionId: positionId,
                    vaultId: vaultId,
                    vTokensAmount: vTokenDesired,
                    nftIds: nftIds,
                    nftAmounts: nftAmounts,
                    vTokenMin: vTokenMin,
                    wethMin: wethMin,
                    deadline: deadline,
                    forceTimelock: false
                })
            );
        }

        // Send leftovers back to the caller
        uint vTokenRemaining = vToken.balanceOf(address(this));
        if (vTokenRemaining > 0) {
            vToken.transfer(msg.sender, vTokenRemaining);
        }

        uint ethRemaining = payable(address(this)).balance;
        if (ethRemaining > 0) {
            (bool success,) = payable(msg.sender).call{value: ethRemaining}('');
            require(success, 'Unable to refund ETH');
        }

        // Calculate the number of vTokens received, based on the ERC20 and ERC721 provided
        uint vTokensStaked = (vTokenDesired + (nftIds.length * 1 ether)) - (vTokenRemaining - vTokenStartBalance);

        // Calculate the amount of ETH that was taken by the target contract
        uint ethStaked = msg.value - (ethRemaining - ethStartBalance);

        emit Deposit(address(vToken), vTokensStaked, msg.sender);
        emit Deposit(address(weth), ethStaked, msg.sender);

        return (vTokensStaked, ethStaked);
    }

    /**
     * Makes a withdrawal of both tokens from our Uniswap token position.
     *
     * @dev Implements `nonReentrant` through `_withdraw`
     *
     * @param recipient The recipient of the withdrawal
     * @param amount0Min The minimum amount of token0 that should be accounted for the burned liquidity
     * @param amount1Min The minimum amount of token1 that should be accounted for the burned liquidity
     * @param deadline The time by which the transaction must be included to effect the change
     * @param liquidity The amount of liquidity to withdraw against
     */
    function withdraw(address recipient, uint amount0Min, uint amount1Min, uint deadline, uint128 liquidity)
        external
        onlyOwner
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        return _withdraw(recipient, amount0Min, amount1Min, deadline, liquidity);
    }

    /**
     * Makes a call to a strategy to withdraw a percentage of the deposited holdings.
     *
     * @dev Implements `nonReentrant` through `_withdraw`
     */
    function withdrawPercentage(address /* recipient */, uint /* percentage */) external view override onlyOwner returns (address[] memory, uint[] memory) {
        // We currently don't implement a percentage withdraw for these strategies as it
        // would require on-chain slippage calculation that could be sandwiched.
        return (validTokens(), new uint[](2));
    }

    function _withdraw(
        address recipient,
        uint amount0Min,
        uint amount1Min,
        uint deadline,
        uint128 liquidity
    )
        internal
        nonReentrant
        returns (address[] memory tokens_, uint[] memory amounts_)
    {
        // If we don't have a position ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (positionId == 0) {
            return (tokens_, amounts_);
        }

        // We need to frontrun the liquidity removal to harvest rewards as the `removeLiquidity`
        // function will collect during the process without us having knowledge of it otherwise.
        harvest(IStrategyFactory(owner()).treasury());

        // Burns liquidity stated, amount0Min and amount1Min are the least you get for
        // burning that liquidity (else reverted).
        router.removeLiquidity(
            INFTXRouter.RemoveLiquidityParams({
                positionId: positionId,  // the position id to withdraw liquidity from
                vaultId: vaultId,  // vault id corresponding to the vTokens in this position
                nftIds: new uint[](0),  // array of nft ids to redeem with the vTokens (can be empty to just receive vTokens)
                vTokenPremiumLimit: 0,  // The max net premium in vTokens the user is willing to pay to redeem nftIds, else tx reverts
                liquidity: liquidity,  // the liquidity amount to burn and withdraw
                amount0Min: amount0Min,  // Minimum amount of token0 to be withdrawn
                amount1Min: amount1Min,  // Minimum amount of token1 to be withdrawn
                deadline: deadline  // deadline after which the tx fails
            })
        );

        // Transfer our withdrawals to the recipient
        uint vTokenBalance = vToken.balanceOf(address(this));
        uint ethBalance = payable(address(this)).balance;

        if (vTokenBalance > 0) {
            vToken.transfer(recipient, vTokenBalance);
            emit Withdraw(address(vToken), vTokenBalance, recipient);
        }

        if (ethBalance > 0) {
            weth.deposit{value: ethBalance}();
            weth.transfer(recipient, ethBalance);
            emit Withdraw(address(weth), ethBalance, recipient);
        }

        tokens_ = validTokens();
        amounts_ = new uint[](2);
        amounts_[0] = vTokenBalance;
        amounts_[1] = ethBalance;
    }

    /**
     * Gets rewards that are available to harvest.
     */
    function available() public view override returns (address[] memory tokens_, uint[] memory amounts_) {
        tokens_ = validTokens();

        // If we don't have a position ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (positionId == 0) {
            amounts_ = new uint[](2);
        } else {
            // Get our token information from our position
            (
                ,,
                address token0,
                address token1,
                ,,,
                uint128 liquidity,
                uint feeGrowthInside0LastX128,
                uint feeGrowthInside1LastX128,
                uint128 positionTokensOwed0,
                uint128 positionTokensOwed1
            ) = positionManager.positions(positionId);

            // If we have liquidity in our position, then we need additional calculation
            if (liquidity > 0) {
                // Load our Uniswap Pool information
                IUniswapV3Pool _pool = IUniswapV3Pool(pool);

                // Get our slot0 tick and the global feeGrowth for both tokens
                (, int24 tickCurrent,,,,,) = _pool.slot0();
                uint feeGrowthGlobal0X128 = _pool.feeGrowthGlobal0X128();
                uint feeGrowthGlobal1X128 = _pool.feeGrowthGlobal1X128();

                // We need to store our inside growth outside of unchecked statement so
                // that it persists.
                uint feeGrowthInside0X128;
                uint feeGrowthInside1X128;

                unchecked {
                    // Get the outside growth from the upper and lower ticks
                    (,, uint feeGrowthOutsideLower0, uint feeGrowthOutsideLower1,,,,) = _pool.ticks(tickLower);
                    (,, uint feeGrowthOutsideUpper0, uint feeGrowthOutsideUpper1,,,,) = _pool.ticks(tickUpper);

                    // Calculate fee growth below from the lower tick
                    uint256 feeGrowthBelow0X128;
                    uint256 feeGrowthBelow1X128;
                    if (tickCurrent >= tickLower) {
                        feeGrowthBelow0X128 = feeGrowthOutsideLower0;
                        feeGrowthBelow1X128 = feeGrowthOutsideLower1;
                    } else {
                        feeGrowthBelow0X128 = feeGrowthGlobal0X128 - feeGrowthOutsideLower0;
                        feeGrowthBelow1X128 = feeGrowthGlobal1X128 - feeGrowthOutsideLower1;
                    }

                    // Calculate fee growth above from the upper tick
                    uint256 feeGrowthAbove0X128;
                    uint256 feeGrowthAbove1X128;
                    if (tickCurrent < tickUpper) {
                        feeGrowthAbove0X128 = feeGrowthOutsideUpper0;
                        feeGrowthAbove1X128 = feeGrowthOutsideUpper1;
                    } else {
                        feeGrowthAbove0X128 = feeGrowthGlobal0X128 - feeGrowthOutsideUpper0;
                        feeGrowthAbove1X128 = feeGrowthGlobal1X128 - feeGrowthOutsideUpper1;
                    }

                    // Use this to determine the growth inside the range
                    feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
                    feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
                }

                // Calculate the accrued fees for each token
                positionTokensOwed0 += uint128(FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128));
                positionTokensOwed1 += uint128(FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128));
            }

            amounts_ = new uint[](2);
            amounts_[0] = (tokens_[0] == token0) ? uint(positionTokensOwed0) : uint(positionTokensOwed1);
            amounts_[1] = (tokens_[1] == token1) ? uint(positionTokensOwed1) : uint(positionTokensOwed0);
        }
    }

    /**
     * There will never be any rewards to harvest in this strategy.
     */
    function harvest(address _recipient) public override onlyOwner {
        // If we don't have a token ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (positionId == 0) return;

        // Collect fees from the pool aand send them directly to the recipient
        (uint amount0, uint amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: positionId,
                recipient: _recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // This should always be our vToken amount
        if (amount0 != 0) {
            lifetimeRewards[address(vToken)] += amount0;
            emit Harvest(address(vToken), amount0);
        }

        // This should always be a WETH amount, so we don't need to convert this
        // from ETH to WETH.
        if (amount1 != 0) {
            lifetimeRewards[address(weth)] += amount1;
            emit Harvest(address(weth), amount1);
        }
    }

    /**
     * Gets the token balance currently in the Uniswap V3 pool.
     *
     * @return token0Amount The amount of token0 in the pool
     * @return token1Amount The amount of token0 in the pool
     * @return liquidity The amount of liquidity for the tokens
     */
    function tokenBalances() public view returns (uint token0Amount, uint token1Amount, uint128 liquidity) {
        // If we don't have a token ID created, then we want to prevent further
        // processing as this would result in a revert.
        if (positionId == 0) {
            return (token0Amount, token1Amount, liquidity);
        }

        // Get our `sqrtPriceX96` from the `slot0`
        (uint160 _sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();

        // Using TickMath, we can get the sqrtRatio for each token
        uint160 _sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 _sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        // Get our liquidity for our position
        (,,,,,,, liquidity,,,,) = positionManager.positions(positionId);

        // Calculate the token amounts for the given liquidity
        (token0Amount, token1Amount) = LiquidityAmounts.getAmountsForLiquidity(_sqrtPriceX96, _sqrtRatioAX96, _sqrtRatioBX96, liquidity);
    }

    /**
     * Returns an array of tokens that the strategy supports.
     */
    function validTokens() public view override returns (address[] memory tokens_) {
        tokens_ = new address[](2);
        tokens_[0] = address(vToken);
        tokens_[1] = address(weth);
    }

    /**
     * Implementing `onERC721Received` so this contract can receive custody of erc721 tokens.
     *
     * @dev Note that the operator is recorded as the owner of the deposited NFT.
     */
    function onERC721Received(address, address, uint, bytes calldata) external view returns (bytes4) {
        // Ensure that the sender of the ERC721 is the Uniswap position manager
        require(msg.sender == address(positionManager), 'Not a Uniswap NFT');
        return this.onERC721Received.selector;
    }

    /**
     * Allows our strategy to receive ETH refunds back from the {NFTXRouter} when not
     * fully utilised. This should be refunded in the `payable` functions that call it.
     *
     * When we receive ETH, we want to wrap it into WETH so that it becomes properly
     * accounted for more easily.
     */
    receive() external payable {
        //
    }

}
