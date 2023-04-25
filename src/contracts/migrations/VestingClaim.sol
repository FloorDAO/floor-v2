// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {IFLOOR} from '@floor-interfaces/tokens/Floor.sol';
import {ITreasury} from '@floor-interfaces/Treasury.sol';


/**
 * Handles the migration of remaining claimable FLOOR tokens. This will be a
 * slightly manual process as it requires the {RemainingVestingFloor} report
 * to be run before time to determine the amount of FLOOR tokens that should
 * be allocated, and to which addresses.
 */
contract VestingClaim is Ownable {

    IFLOOR public immutable FLOOR;
    IERC20 public immutable WETH;
    ITreasury private immutable treasury;

    // Tracks available allocations
    mapping(address => uint) internal allocation;


    constructor(address _floor, address _weth, address _treasury) {
        require(_floor != address(0), "Zero address: FLOOR");
        require(_weth != address(0), "Zero address: WETH");
        require(_treasury != address(0), "Zero address: Treasury");

        FLOOR = IFLOOR(_floor);
        WETH = IERC20(_weth);
        treasury = ITreasury(_treasury);
    }

    /**
     * Allows wallet to claim FLOOR. We multiply by 1e6 as we convert the FLOOR from
     * a WETH finney.
     *
     * @param _to address The address that is claiming
     * @param _amount uint256 The amount being claimed in FLOOR (18 decimals)
     */
    function claim(address _to, uint256 _amount) external {
        // Ensure that we have sufficient FLOOR allocation to claim against
        require(allocation[msg.sender] >= _amount, 'Insufficient allocation');

        // Transfer the WETH to the {Treasury}
        WETH.transferFrom(msg.sender, address(treasury), _amount / 1e3);

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
     * Assign a range of FLOOR allocation to addresses.
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
