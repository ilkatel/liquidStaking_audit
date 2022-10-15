//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface IMasterChef {
    function deposit(uint256 pid, uint256 amount, address to) external;
    function withdraw(uint256 pid, uint256 amount, address to) external;
    function pendingARSW(uint256 pid, address user) external view returns (uint256);
    function harvest(uint256 pid, address to) external;
}