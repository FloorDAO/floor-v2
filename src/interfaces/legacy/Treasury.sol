// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.7.5;

interface ILegacyTreasury {
    function bondCalculator(address _address) external view returns (address);

    function deposit(uint _amount, address _token, uint _profit) external returns (uint);

    function withdraw(uint _amount, address _token) external;

    function depositERC721(address _token, uint _tokenId) external;

    function withdrawERC721(address _token, uint _tokenId) external;

    function tokenValue(address _token, uint _amount) external view returns (uint value_);

    function mint(address _recipient, uint _amount) external;

    function manage(address _token, uint _amount) external;

    function allocatorManage(address _token, uint _amount) external;

    function claimNFTXRewards(address _liquidityStaking, uint _vaultId, address _rewardToken) external;

    function incurDebt(uint amount_, address token_) external;

    function repayDebtWithReserve(uint amount_, address token_) external;

    function excessReserves() external view returns (uint);

    function riskOffValuation(address _token) external view returns (uint);

    function baseSupply() external view returns (uint);

    function enable(uint8 _status, address _address, address _calculator) external;
}
