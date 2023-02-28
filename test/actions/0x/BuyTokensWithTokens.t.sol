// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import {BuyTokensWithTokens} from '@floor/actions/0x/BuyTokensWithTokens.sol';

import '../../utilities/Environments.sol';

// TODO: Regenerate tx data: https://docs.0x.org/0x-api-swap/api-references/get-swap-v1-quote
contract ZeroXBuyTokensWithTokensTest is FloorTest {

    // Mainnet 0x swapTarget contract
    address internal constant ZEROX_CONTRACT = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    /// Mainnet WETH contract
    address public immutable ETH  = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ..
    address BUY_TOKEN  = 0x111111111117dC0aa78b770fA6A738034120C302;  // 1Inch
    address SELL_TOKEN = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;  // AAVE

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_726_103;

    // Store our action contract
    BuyTokensWithTokens action;

    // Store the treasury address
    address treasury;

    constructor() forkBlock(BLOCK_NUMBER) {
        // Set up a test address to be our {Treasury}
        treasury = users[1];

        // Set up a WrapEth action
        action = new BuyTokensWithTokens(ZEROX_CONTRACT, treasury);
    }

    function test_CanBuyTokensWithERC20() external {
        deal(SELL_TOKEN, treasury, 100 ether);

        vm.prank(treasury);
        IERC20(SELL_TOKEN).approve(address(action), 100 ether);

        bytes memory txData = hex'6af479b200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000078455d3367d95cd70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000427fc66500c84a76ad7e9c93437bfc5ac33e2ddae9000bb8a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48002710111111111117dc0aa78b770fa6a738034120c302000000000000000000000000000000000000000000000000000000000000869584cd0000000000000000000000001000000000000000000000000000000000000011000000000000000000000000000000000000000000000049ea8f9b3263fdd91b';
        uint received = action.execute(abi.encode(SELL_TOKEN, BUY_TOKEN, txData));

        assertEq(received, 140063680022460655707);
        assertEq(IERC20(SELL_TOKEN).balanceOf(treasury), 99 ether);
        assertEq(IERC20(BUY_TOKEN).balanceOf(treasury), received);
    }

    function test_CanBuyTokensWithWeth() external {
        deal(WETH, treasury, 1 ether);
        vm.prank(treasury);
        IERC20(WETH).approve(address(action), 1 ether);

        uint received = action.execute(
            abi.encode(
                WETH,
                BUY_TOKEN,
                hex'6af479b200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000097497b68b8fb6bacc800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000064a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48002710111111111117dc0aa78b770fa6a738034120c302000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000336f9763a363fdd96d'
            )
        );

        assertEq(received, 2818252655420925357752);
        assertEq(IERC20(WETH).balanceOf(treasury), 0);
        assertEq(IERC20(BUY_TOKEN).balanceOf(treasury), received);
    }

    function test_CanBuyTokensWithEth() external {
        uint received = action.execute{value: 10 ether}(
            abi.encode(
                ETH,
                BUY_TOKEN,
                hex'6af479b200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000097497b68b8fb6bacc800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000064a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48002710111111111117dc0aa78b770fa6a738034120c302000000000000000000000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000336f9763a363fdd96d'
            )
        );

        assertEq(received, 2818252655420925357752);
        assertEq(IERC20(WETH).balanceOf(treasury), 9000000000000000000);
        assertEq(IERC20(BUY_TOKEN).balanceOf(treasury), received);
    }

    function test_CanSellTokensForWeth() external {
        deal(SELL_TOKEN, treasury, 100 ether);

        vm.prank(treasury);
        IERC20(SELL_TOKEN).approve(address(action), 100 ether);

        uint received = action.execute(
            abi.encode(
                SELL_TOKEN,
                WETH,
                hex'd9627aa400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000a9987681dd154f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000007fc66500c84a76ad7e9c93437bfc5ac33e2ddae9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2869584cd000000000000000000000000100000000000000000000000000000000000001100000000000000000000000000000000000000000000006c16eee5f763fdd988'
            )
        );

        assertEq(received, 48219096784256084);
        assertEq(IERC20(SELL_TOKEN).balanceOf(treasury), 99 ether);
        assertEq(IERC20(WETH).balanceOf(treasury), received);
    }

    function test_CannotBuyTokensWithInsufficientBalance() external {
        vm.expectRevert();
        action.execute(
            abi.encode(
                SELL_TOKEN,
                BUY_TOKEN,
                hex'415565b0000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000c613ca40b93361c3372afd00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000015e000000000000000000000000000000000000000000000000000000000000016a0000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000152000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000014e000000000000000000000000000000000000000000000000000000000000014e000000000000000000000000000000000000000000000000000000000000013200000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014e0000000000000000000000000000000000000000000000000000000000000000d00000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000005a000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000007e000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000be00000000000000000000000000000000000000000000000000000000000000d400000000000000000000000000000000000000000000000000000000000000e200000000000000000000000000000000000000000000000000000000000000f8000000000000000000000000000000000000000000000000000000000000010a000000000000000000000000000000002556e6973776170563200000000000000000000000000000000000000000000000000000000000000011149218307b13c00000000000000000000000000000000000000000002cae042f3b3e32c3168ad000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000f164fc0ec4e93095b804a4795bbe1e041497b92a00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000002556e6973776170563200000000000000000000000000000000000000000000000000000000000000011149218307b13c0000000000000000000000000000000000000000000458178be08a61cc5c4393000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000f164fc0ec4e93095b804a4795bbe1e041497b92a00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000002556e6973776170563200000000000000000000000000000000000000000000000000000000000000011149218307b13c00000000000000000000000000000000000000000003443b7ee72166109d3612000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000f164fc0ec4e93095b804a4795bbe1e041497b92a00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000143757276650000000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000000c977a8b717ffed890460000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000008000000000000000000000000006364f10b501e868329afbc005b3492902d6c763a6417ed600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000143757276650000000000000000000000000000000000000000000000000000000000000000000000011149218307b13c0000000000000000000000000000000000000000000ee9b048fc29eb26943d5700000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000a5407eae9ba41422680e2e00537571bcc53efbfda6417ed600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000143757276650000000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000a15cf3f11f14dfd95086af00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c73df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d42616e636f7200000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000002b8f2f36f0e6334ab457000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001000000000000000000000000002f9ec37d6ccfff1cab21733bdadede11c823ccb000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000005000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000005365b5bc56493f08a38e5eb08e36cbbe6fcc83060000000000000000000000001f573d6fb3f13d689ff844b4ce37794d79a7ff1c000000000000000000000000e5df055773bf9710053923599504831c7dbdd6970000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000001c42616e636f7256330000000000000000000000000000000000000000000000000000000000000000011149218307b13c00000000000000000000000000000000000000000000f22281ac5794c1709c42000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000eef417e1d5cc832e619ae18d2f140de2999dd4fb00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000253757368695377617000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000024510c3e6b18bfc604e4f000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000d9e1ce17f2641f24ae83637ab66a2cca9c378b9f00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000b446f646f563200000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000023e19972dca2a885e66f7000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000400000000000000000000000003058ef90929cb8180174d74c507176cca6835d7300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c43727970746f436f6d00000000000000000000000000000000000000000000000000000000000000011149218307b13c0000000000000000000000000000000000000000000007fe74f53d92bcfa60f7000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000ceb90e4c17d626be0facd78b79c9c87d7ca181b300000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000f536164646c6500000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000002c6c545dee1fe5d83a0d00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000acb83e0633d6605c5001e2ab59ef3c745547c8c79169558600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f53796e61707365000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000058414690c3387dd037e1d000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000800000000000000000000000001116898dda4015ed8ddefb84b6e8bc24528af2d8916955860000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000600000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000c813fd8b8e61505fd0d826000000000000000000000000af5889d80b0f6b2850ec5ef8aad0625788eeb903000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd0000000000000000000000001000000000000000000000000000000000000011000000000000000000000000000000000000000000000052dbd76a1b63e3afc1'
            )
        );
    }

}
