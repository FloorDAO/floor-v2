// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '../../../src/contracts/actions/0x/BuyTokensWithTokens.sol';

import '../../utilities/Environments.sol';

contract BuyTokensWithTokensTest is FloorTest {

    // Mainnet 0x swapTarget contract
    address internal constant ZEROX_CONTRACT = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    /// Mainnet WETH contract
    address public immutable ETH  = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // ..
    address BUY_TOKEN  = 0x111111111117dC0aa78b770fA6A738034120C302;  // 1Inch
    address SELL_TOKEN = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;  // AAVE

    // Store our mainnet fork information
    uint internal constant BLOCK_NUMBER = 16_134_863;

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
        emit log('111');
        deal(treasury, SELL_TOKEN, 1 ether);

        emit log('222');
        vm.prank(treasury);
        IERC20(SELL_TOKEN).approve(address(action), 1 ether);

        emit log('333');

        bytes memory txData = '0xd9627aa400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000082c9d99a88067ae28000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000007fc66500c84a76ad7e9c93437bfc5ac33e2ddae9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000111111111117dc0aa78b770fa6a738034120c302869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000612d72e3c263e3b618';
        uint received = action.execute(abi.encode(SELL_TOKEN, BUY_TOKEN, txData));

        emit log('444');

        assertEq(received, 0);
        assertEq(IERC20(SELL_TOKEN).balanceOf(treasury), 0);
        assertEq(IERC20(BUY_TOKEN).balanceOf(treasury), received);
    }

    function test_CanBuyTokensWithWeth() external {
        deal(treasury, WETH, 1 ether);
        vm.prank(treasury);
        IERC20(WETH).approve(address(action), 1 ether);

        uint received = action.execute(
            abi.encode(
                WETH,
                BUY_TOKEN,
                '0x3598d8ab0000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000059ebc44788f3578d6e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f46b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000f9a6da8ad363e39324'
            )
        );

        assertEq(received, 0);
        assertEq(IERC20(WETH).balanceOf(treasury), 0);
        assertEq(IERC20(BUY_TOKEN).balanceOf(treasury), received);
    }

    function test_CanBuyTokensWithEth() external {
        uint received = action.execute(
            abi.encode(
                WETH,
                BUY_TOKEN,
                '0x6af479b200000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000059ad6c0276d0cdac500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f46b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000bf83971d8d63e3b012'
            )
        );

        assertEq(received, 0);
    }

    function test_CanSellTokensForWeth() external {
        uint received = action.execute(
            abi.encode(
                SELL_TOKEN,
                WETH,
                '0xd9627aa400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000002187a7e5fc4a7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000f4f55713b363e3b04c'
            )
        );

        assertEq(received, 0);
    }

    function test_CanSellTokensForEth() external {
        uint received = action.execute(
            abi.encode(
                SELL_TOKEN,
                ETH,
                '0xd9627aa400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000de0b6b3a76400000000000000000000000000000000000000000000000000000002187a7e5fc4a7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee869584cd00000000000000000000000010000000000000000000000000000000000000110000000000000000000000000000000000000000000000136ce2da5163e3b056'
            )
        );

        assertEq(received, 0);
    }

    function test_CannotBuyTokensWithInsufficientBalance() external {
        vm.expectRevert();
        action.execute(
            abi.encode(
                SELL_TOKEN,
                BUY_TOKEN,
                '0x415565b0000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000c613ca40b93361c3372afd00000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000015e000000000000000000000000000000000000000000000000000000000000016a0000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000152000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000014e000000000000000000000000000000000000000000000000000000000000014e000000000000000000000000000000000000000000000000000000000000013200000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014e0000000000000000000000000000000000000000000000000000000000000000d00000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000002e0000000000000000000000000000000000000000000000000000000000000044000000000000000000000000000000000000000000000000000000000000005a000000000000000000000000000000000000000000000000000000000000006c000000000000000000000000000000000000000000000000000000000000007e000000000000000000000000000000000000000000000000000000000000009000000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000be00000000000000000000000000000000000000000000000000000000000000d400000000000000000000000000000000000000000000000000000000000000e200000000000000000000000000000000000000000000000000000000000000f8000000000000000000000000000000000000000000000000000000000000010a000000000000000000000000000000002556e6973776170563200000000000000000000000000000000000000000000000000000000000000011149218307b13c00000000000000000000000000000000000000000002cae042f3b3e32c3168ad000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000f164fc0ec4e93095b804a4795bbe1e041497b92a00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000002556e6973776170563200000000000000000000000000000000000000000000000000000000000000011149218307b13c0000000000000000000000000000000000000000000458178be08a61cc5c4393000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000f164fc0ec4e93095b804a4795bbe1e041497b92a00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000002556e6973776170563200000000000000000000000000000000000000000000000000000000000000011149218307b13c00000000000000000000000000000000000000000003443b7ee72166109d3612000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000f164fc0ec4e93095b804a4795bbe1e041497b92a00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000143757276650000000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000000c977a8b717ffed890460000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000008000000000000000000000000006364f10b501e868329afbc005b3492902d6c763a6417ed600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000143757276650000000000000000000000000000000000000000000000000000000000000000000000011149218307b13c0000000000000000000000000000000000000000000ee9b048fc29eb26943d5700000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000a5407eae9ba41422680e2e00537571bcc53efbfda6417ed600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000143757276650000000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000a15cf3f11f14dfd95086af00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000bebc44782c7db0a1a60cb6fe97d0b483032ff1c73df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d42616e636f7200000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000002b8f2f36f0e6334ab457000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001000000000000000000000000002f9ec37d6ccfff1cab21733bdadede11c823ccb000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000005000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000005365b5bc56493f08a38e5eb08e36cbbe6fcc83060000000000000000000000001f573d6fb3f13d689ff844b4ce37794d79a7ff1c000000000000000000000000e5df055773bf9710053923599504831c7dbdd6970000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000001c42616e636f7256330000000000000000000000000000000000000000000000000000000000000000011149218307b13c00000000000000000000000000000000000000000000f22281ac5794c1709c42000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000eef417e1d5cc832e619ae18d2f140de2999dd4fb00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000253757368695377617000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000024510c3e6b18bfc604e4f000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000d9e1ce17f2641f24ae83637ab66a2cca9c378b9f00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000b446f646f563200000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000023e19972dca2a885e66f7000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000400000000000000000000000003058ef90929cb8180174d74c507176cca6835d7300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c43727970746f436f6d00000000000000000000000000000000000000000000000000000000000000011149218307b13c0000000000000000000000000000000000000000000007fe74f53d92bcfa60f7000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000ceb90e4c17d626be0facd78b79c9c87d7ca181b300000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000003000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000f536164646c6500000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000002c6c545dee1fe5d83a0d00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000acb83e0633d6605c5001e2ab59ef3c745547c8c79169558600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f53796e61707365000000000000000000000000000000000000000000000000000000000000000000011149218307b13c000000000000000000000000000000000000000000058414690c3387dd037e1d000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000800000000000000000000000001116898dda4015ed8ddefb84b6e8bc24528af2d8916955860000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000600000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000c813fd8b8e61505fd0d826000000000000000000000000af5889d80b0f6b2850ec5ef8aad0625788eeb903000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec7000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000000000000000000000000000000000000000000000000000000869584cd0000000000000000000000001000000000000000000000000000000000000011000000000000000000000000000000000000000000000052dbd76a1b63e3afc1'
            )
        );
    }

}
