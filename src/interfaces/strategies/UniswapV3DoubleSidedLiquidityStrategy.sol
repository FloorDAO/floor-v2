// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * https://docs.uniswap.org/protocol/reference/core/UniswapV3Pool
 * https://etherscan.io/tx/0x9da1baff6c4b33468875a16f79ea73967f5221f6ed0c10a9285b8ba913ac79fb
 */
interface IUniswapV3DoubleSidedLiquidityStrategy {

    /**
     * Return the the address of the yield token.
     */
    function yieldToken() external view returns (address[] calldata);

    /**
     * Return the the address of the underlying token. This will be the same as
     * the yield token for Uniswap V3 positions.
     */
    function underlyingToken() external view returns (address[] calldata);

    /**
     * A deposit of token0 and token1 that will increase the liquidity position of
     * the existing UniswapV3 pool. We will need to verify that the token amounts
     * provided match our existing token ratio, but this should be handled by Uniswap
     * in their function calls.
     *
     * We will call `increaseLiquidity` on the {INonfungiblePositionManager}.
     *
     * This liquidity must be infinite range.
     *
     * If this is the first time a deposit has been made, then we will need to
     * initialise our pool, minting the ERC721 and storing it within this
     * strategy as the owner.
     *
     * https://docs.uniswap.org/protocol/guides/providing-liquidity/increase-liquidity
     */
    function deposit(address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata yieldAmount_);

    /**
     * Harvest potential rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * To harvest our fees, we can simply calls the `collect` function against our pool's
     * ERC721 token.
     *
     * https://docs.uniswap.org/protocol/guides/providing-liquidity/collect-fees
     */
    function harvest() external returns (address[] calldata token_, uint256[] calldata returnAmount_);

    /**
     * Allows a staked user to exit their strategy position. For UV3, we will need to
     * reduce our liquidity offering within the user's staked position.
     *
     * We can use the `_amount` function parameter to specify set token IDs that will be
     * exited and send it to Uniswap by calling `decreaseLiquidity` on the
     * {NonfungiblePositionManager}.
     *
     * https://docs.uniswap.org/protocol/guides/providing-liquidity/decrease-liquidity
     */
    function exit(address _recipient, address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata returnAmount_);

}
