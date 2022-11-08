// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * https://sudoswap.xyz/#/manage/0xf99A0383921ee80D86f531B809DBC94a8422E06C
 * https://etherscan.io/tx/0x6b1f0ee0ec425b68e903a3b839cb6a13201255df4b6de7d2477219316892bdff
 */
interface ISudoswapDoubleSidedLiquidityStrategy {

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
     * the existing Sudoswap pool. We will need to verify that the token amounts
     * provided match our existing token ratio. This should be handled by Sudoswap
     * in their function calls, but we can get the `delta`, `NFTQuote` and `spotPrice`
     * data from the contract.
     *
     * We will call `increaseLiquidity` on the {INonfungiblePositionManager}.
     *
     * If this is the first time a deposit has been made, then we will need to
     * initialise our pool using the `initialize` call and storing it within this
     * strategy as the owner.
     *
     * When a deposit is made, we can just send it directly to the contract and the
     * contract's {onERC721Received} and {receive} functions handle the logic from
     * there.
     */
    function deposit(address[] calldata _token, uint256[] calldata _amount) external returns (address[] calldata token_, uint256[] calldata yieldAmount_);

    /**
     * Harvest potential rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * To harvest our fees, we will need to determine the ETH change and then make
     * requests to withdraw the difference. We would be interested in both ETH and
     * token gain.
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
