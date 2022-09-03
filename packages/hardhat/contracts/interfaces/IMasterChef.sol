//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface IMasterChef {
    function deposit(uint256 pid, uint256 amount, address to) external;
}