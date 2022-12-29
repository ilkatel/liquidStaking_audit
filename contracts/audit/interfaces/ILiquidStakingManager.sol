// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ILiquidStakingManager {
    function getAddress(bytes4 selector) external view returns (address);
}