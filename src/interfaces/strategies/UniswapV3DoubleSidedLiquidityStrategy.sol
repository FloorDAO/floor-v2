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
    function yieldToken() external view returns (address[]);

    /**
     * Return the the address of the underlying token. This will be the same as
     * the yield token for Uniswap V3 positions.
     */
    function underlyingToken() external view returns (address[]);

    /**
     * Deposit underlying ERC721 token. This token represents a users position between
     * two tokens (token0 and token1) on Uniswap, allowing the strategy to subsequently
     * collect rewards and manage the position.
     *
     * @param _amount Deprecated in UV3 strategy
     *
     * @return _yieldAmount The amount of yield token deposited.
     */
    function deposit(uint256 _amount) external returns (uint256 _yieldAmount[]);

    /**
     * Harvest possible rewards from strategy. The rewards generated from the strategy
     * will be sent to the Treasury and minted to FLOOR (if not paused), which will in
     * turn be made available in the {RewardsLedger}.
     *
     * - Call `collect` against each of the ERC721 stored in the vault
     *
     * @return _returnAmount The amount of yield token harvested.
     */
    function harvest() external returns (uint256 _returnAmount[]);

    /**
     * Allows a staked user to exit their strategy position. For UV3, this will just mean
     * reward yield will be harvested and then the user's ERC721 tokens will be withdrawn
     * from the vault.
     *
     * We can use the `_amount` function parameter to specify set token IDs that will be
     * exited.
     *
     * @return _returnAmount The amount of underlying token claimed from exit.
     */
    function exit(address _recipient, uint256 _amount[]) external returns (uint256 _returnAmount[]);

    /**
     * Emergency function to execute arbitrary call.
     *
     * This function should be only used in case of emergency. It should never be called explicitly
     * in any contract in normal case, and should only be available to guardian or governor.
     *
     * @param _to The address of target contract to call.
     * @param _value The value passed to the target contract.
     * @param _data The calldata pseed to the target contract.
     */
    function execute(address _to, uint256 _value, bytes calldata _data) external payable returns (bool, bytes memory);

}
