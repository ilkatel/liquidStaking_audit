//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface ISiriusFarm {
    function deposit(uint256 value, address account, bool _claimRewards) external;
    function withdraw(uint256 value,bool _claimRewards) external;
    function claimRewards(address _addr, address _receiver) external;
    function claimableTokens(address _addr) external returns (uint256);
}
