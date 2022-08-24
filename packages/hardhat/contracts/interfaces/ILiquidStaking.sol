// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface ILiquidStaking {
    function addStaker(
        address,
        string memory,
        string memory
    ) external;

    function isStaker(address) external view returns (bool);

    function isLpToken(address) external view returns (bool);

    function hasLpToken(address) external view returns (bool);

    function currentEra() external view returns (uint);

    function setFirstEra(address _staker, uint _era) external;

    function addToBuffer(address _user, uint _amount) external;

    function setBuffer(address _user, uint _amount) external;

    function buffer(address _user, uint _era) external view returns (uint);
}
