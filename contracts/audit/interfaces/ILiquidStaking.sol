// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ILiquidStaking {
    function addStaker(
        address,
        string memory ) external;

    function isStaker(address) external view returns (bool);
    function currentEra() external view returns (uint);
    function updateUserBalanceInUtility(string memory, address) external;
    function updateUserBalanceInAdapter(string memory, address) external;

    function REVENUE_FEE() external view returns (uint8);
    function sync(uint256 _era) external;
}
