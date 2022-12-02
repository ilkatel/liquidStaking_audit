// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface INFTDistributor {
    function getUserEraBalance(string memory utility, address _user, uint256 era) external view returns (uint256, bool);
    function getUserFee(string memory utility, address _user) external view returns (uint8);
    function updateUser(string memory utility, address _user, uint256 era, uint256 value) external;
    function getErasData(uint256 eraBegin, uint256 eraEnd) external returns (uint256[2] memory totalData);
    function isUnique(string memory utility) external view returns (bool);
    function getDefaultUserFee(address _user) external view returns (uint8);
    function updateUserFee(address user, uint8 fee, uint256 era) external;
    function getUserEraFee(address user, uint256 era) external view returns (uint8);
    function getBestUtilFee(string memory utility, uint8 fee) external view returns (uint8);
    function getEra(uint256 era) external view returns (uint256[2] memory);
    function updates() external;
}
