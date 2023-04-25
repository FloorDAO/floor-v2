// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'forge-std/console.sol';
import 'forge-std/Script.sol';

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";


struct Term {
    uint256 percent; // 4 decimals ( 5000 = 0.5% )
    uint256 gClaimed; // rebase-agnostic number
    uint256 max; // maximum nominal FLOOR amount can claim, 9 decimal
}


interface IVestingClaim {
    function terms(address) external view returns (Term memory);
    function redeemableFor(address) external view returns (uint);
    function claimed(address) external view returns (uint);
    function circulatingSupply() external view returns (uint);
}


/**
 * Displays a table showing the amount of FLOOR that should be allocated to each
 * address when we upgrade to V2. Before these values are actually reallocated, we
 * need to pause the existing `VestingClaim` contract from V1.
 */
contract PFloorHolderBalances {

    // Accorcing to Etherscan, the amount of FLOOR claimed by an address
    mapping (address => uint) internal _claimed;

    // Reference our existing {VestingClaim} contract
    IVestingClaim vesting = IVestingClaim(0x8Cbc813576eD14Fc1C27bC1A791360b8339489e6);

    function run() external {
        // Store a list of all contract addresses that have been allocated terms
        address[21] memory pFloorHolders = [
            0x7b0a39EC4B38Ec527bc9Db669107632c02959C4b,
            0x44373fa186a86Edf35C20FEE3ff72ffD9e82560d,
            0x2FA7E23d3266a076e303a791197e763C9b8599f1,
            0xbAa3c208929af3B5a578a8EB1289238574eE6aCe,
            0xB19C1f85e9f939f98935Fb0877A95B32E7306e60,
            0x3B85db7f2B97B6b8cF988b06F7Ba362C5B28B475,
            0x10877B0c8556095a5c9aee62a757410CD1e9554E,
            0x0f294726A2E3817529254F81e0C195b6cd0C834f,
            0x52Df1b10fA2e1710d41D0509d198628ad9586719,
            0x3070C3499D3233Dea493dc86E5aa9dAF3ad1bD83,
            0x38A19ADFe4859e82811E6544c6b97985D1ed6A4f,
            0xb1b117a45aD71d408eb55475FC3A65454edCc94A,
            0x74eF9dB672f7B11A5D88a0046Eeabb26988F980a,
            0x8F217D5cCCd08fD9dCe24D6d42AbA2BB4fF4785B,
            0xB3e8ea64928afa84dc9A8464F0787EBb42525999,
            0x299A742242Ca1506490828ec4fA51bF48A5ed9F3,
            0xC904Fd0Ce2EF60F05ed2aa0741BD9cE41091e376,
            0x167539702B5501aADd9B0B85E53532Fd57cC71a9,
            0x81a1F6715b32CE3038e941cC2b3C079eBAd16f67,
            0xfA64669BCB2D5Ef351CCbE0d0396b8DE3CB1D7e2,
            0x40D73Df4F99bae688CE3C23a01022224FE16C7b2
        ];

        // To save from scraping Etherscan, list in/out transactions (9 decimal). This
        // snapshot was taked 25th April, 2023 at 11:30am.
        _claimed[0xfA64669BCB2D5Ef351CCbE0d0396b8DE3CB1D7e2] += 100_000000000;
        _claimed[0x0f294726A2E3817529254F81e0C195b6cd0C834f] += 2000_000000000;
        _claimed[0x7b0a39EC4B38Ec527bc9Db669107632c02959C4b] += 10000_000000000;
        _claimed[0x299A742242Ca1506490828ec4fA51bF48A5ed9F3] += 316_227473000;
        _claimed[0xb1b117a45aD71d408eb55475FC3A65454edCc94A] += 100_000000000;
        _claimed[0xbAa3c208929af3B5a578a8EB1289238574eE6aCe] += 700_000000000;
        _claimed[0xbAa3c208929af3B5a578a8EB1289238574eE6aCe] += 1219_230000000;
        _claimed[0xbAa3c208929af3B5a578a8EB1289238574eE6aCe] += 2104_830000000;
        _claimed[0xbAa3c208929af3B5a578a8EB1289238574eE6aCe] += 3578_540000000;
        _claimed[0xbAa3c208929af3B5a578a8EB1289238574eE6aCe] += 4397_624560000;
        _claimed[0x44373fa186a86Edf35C20FEE3ff72ffD9e82560d] += 1000_000000000;
        _claimed[0x0f294726A2E3817529254F81e0C195b6cd0C834f] += 1787_123038000;
        _claimed[0xB3e8ea64928afa84dc9A8464F0787EBb42525999] += 690_367961000;
        _claimed[0x3B85db7f2B97B6b8cF988b06F7Ba362C5B28B475] += 4050_000000000;
        _claimed[0x10877B0c8556095a5c9aee62a757410CD1e9554E] += 8373_097900000;
        _claimed[0x3B85db7f2B97B6b8cF988b06F7Ba362C5B28B475] += 4340_000000000;
        _claimed[0x44373fa186a86Edf35C20FEE3ff72ffD9e82560d] += 1000_000000000;
        _claimed[0xb1b117a45aD71d408eb55475FC3A65454edCc94A] += 181_400110000;

        // NFTX multisig claim remaps address
        _claimed[0x40D73Df4F99bae688CE3C23a01022224FE16C7b2] += 29245_752247000;

        // Output our table headers
        console.log('+-----------------------------------------------+--------------------+');
        console.log('| Address                                       | Available FLOOR    |');
        console.log('+-----------------------------------------------+--------------------+');

        // Keep a sum of the total amount of FLOOR to be allocated
        uint totalFloor;

        // Loop through our users to display the amount owed
        for (uint i; i < pFloorHolders.length; ++i) {
            // Pull out our vesting terms from the contract directly, as this avoids a conversion
            // into gFloor that would skew our numbers. This will give us the user's total FLOOR
            // allocation at the current circulating supply.
            Term memory info = vesting.terms(pFloorHolders[i]);
            uint max = (vesting.circulatingSupply() * info.percent) / 1e6;
            if (max > info.max) max = info.max;

            // Reduce the max amount by the amount we have recorded the user to have claimed in
            // FLOOR terms.
            uint amount = max - _claimed[pFloorHolders[i]];

            // Format our output
            string memory line = '| ';
            line = string.concat(line, _addressToString(pFloorHolders[i]));
            line = string.concat(line, '    | ');
            line = string.concat(line, Strings.toString(amount));
            console.log(line);

            // Track our total amount of FLOOR required
            totalFloor += amount;
        }

        // Output the total allocated FLOOR value
        console.log('+-----------------------------------------------+--------------------+');
        console.log('');
        console.log('+-----------------------------------------------+--------------------+');
        console.log(
            string.concat(
                '| TOTAL FLOOR ALLOCATED                         | ',
                Strings.toString(totalFloor)
            )
        );
        console.log('+-----------------------------------------------+--------------------+');
        console.log('');
    }

    /**
     * Converts an address into a string representation of the address. This allows us
     * to concatenate it against an existing string to write to JSON.
     *
     * @param _address The raw address
     *
     * @return string The address in string format
     */
    function _addressToString(address _address) internal pure returns(string memory) {
       bytes32 _bytes = bytes32(uint256(uint160(_address)));
       bytes memory HEX = "0123456789abcdef";
       bytes memory _string = new bytes(42);
       _string[0] = '0';
       _string[1] = 'x';
       for(uint i = 0; i < 20; i++) {
           _string[2+i*2] = HEX[uint8(_bytes[i + 12] >> 4)];
           _string[3+i*2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
       }

       return string(_string);
    }

}
