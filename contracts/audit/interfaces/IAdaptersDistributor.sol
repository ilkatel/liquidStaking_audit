// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IAdaptersDistributor {
    function getUserBalanceInAdapters(address user) external view returns (uint256);
}
