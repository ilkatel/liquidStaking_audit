// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface INDistributor {
    function totalDntInUtil(string memory) external returns (uint256);
    function getTotalDnt(string memory _dnt) external view returns (uint256);
    function getUserDntBalanceInUtil(address, string memory, string memory) external returns (uint256);
    function addUtility(string memory) external;
    function issueDnt(address, uint256, string memory, string memory) external;
    function removeDnt(address, uint256, string memory, string memory) external;
    function listUserUtilitiesInDnt(address _user, string memory _dnt) external view returns (string[] memory);
}
