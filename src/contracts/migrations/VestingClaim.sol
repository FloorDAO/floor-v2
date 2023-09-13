// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20, SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {IFLOOR} from '@floor-interfaces/tokens/Floor.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';

/**
 * Handles the migration of remaining claimable FLOOR tokens. This will be a
 * slightly manual process as it requires the {RemainingVestingFloor} report
 * to be run before time to determine the amount of FLOOR tokens that should
 * be allocated, and to which addresses.
 */
contract VestingClaim is Ownable {
    using SafeERC20 for IERC20;

    /// Stores assigned interfaces
    IFLOOR public immutable FLOOR;
    IERC20 public immutable WETH;
    ITreasury private immutable treasury;

    /// Tracks available allocations
    mapping(address => uint) internal allocation;

    /**
     * Allows our contracts to be set.
     *
     * @param _floor The new {FLOOR} token contract address
     * @param _weth The WETH contract address
     * @param _treasury The {Treasury} contract address
     */
    constructor(address _floor, address _weth, address _treasury) {
        require(_floor != address(0), 'Zero address: FLOOR');
        require(_weth != address(0), 'Zero address: WETH');
        require(_treasury != address(0), 'Zero address: Treasury');

        FLOOR = IFLOOR(_floor);
        WETH = IERC20(_weth);
        treasury = ITreasury(_treasury);
    }

    /**
     * Allows wallet to claim FLOOR. FLOOR can be claimed by paying a backing of 0.001
     * WETH. So if, for example, 1000 FLOOR tokens are to be claimed, then 1 WETH will
     * be transferred to the {Treasury} via this contract.
     *
     * @dev We divide by 1e3 as we convert the 18 decimal FLOOR to a WETH finney, which
     * is 0.001 of an 18 decimal token.
     *
     * @param _to address The address that is claiming
     * @param _amount uint256 The amount being claimed in FLOOR (18 decimals)
     */
    function claim(address _to, uint _amount) external {
        // Ensure that we have sufficient FLOOR allocation to claim against
        require(allocation[msg.sender] >= _amount, 'Insufficient allocation');

        // We ensure that the amount is not 0, and that `_amount % 1e3` equals zero as
        // otherwise it could be exploited to acquire a non-zero amount of FLOOR tokens
        // without transferring any WETH tokens due to the way the 1-to-1000 ratio between
        // the tokens is enforced.
        require(_amount != 0, 'Invalid amount');
        require(_amount % 1e3 == 0, 'Invalid amount');

        // Transfer the WETH to the {Treasury}. This will need to have already been
        // approved by the sender.
        WETH.safeTransferFrom(msg.sender, address(treasury), _amount / 1e3);

        // Reduce the allocation amount from the user. This has already been sanitized
        unchecked {
            allocation[msg.sender] -= _amount;
        }

        // Transfer our FLOOR to the defined recipient
        FLOOR.mint(_to, _amount);
    }

    /**
     * View FLOOR claimable for address.
     *
     * @param _address The wallet address to check allocation of
     *
     * @return uint The amount of FLOOR tokens allocated and available to claim
     */
    function redeemableFor(address _address) public view returns (uint) {
        return allocation[_address];
    }

    /**
     * Assign a range of FLOOR allocation to addresses. This does not use a merkle
     * approach as there is only a small number of addresses that will be available
     * to make a claim against the contract.
     *
     * @dev The token does not need to be transferred with this call as it is minted
     * at point of claim.
     *
     * @param _address The address made available for allocation claims
     * @param _amount The amount of tokens allocated to the corresponding address
     */
    function setAllocation(address[] calldata _address, uint[] calldata _amount) public onlyOwner {
        uint length = _address.length;
        for (uint i; i < length;) {
            unchecked {
                allocation[_address[i]] += _amount[i];
                ++i;
            }
        }
    }
}
