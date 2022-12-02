//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/DappsStaking.sol";

contract mockDapp {
    DappsStaking public DAPPS_STAKING;
    string public uselessString;
    uint256 public lastUpdated;

    constructor() {
        uselessString = "mock";
        DAPPS_STAKING = DappsStaking(payable(0x0000000000000000000000000000000000005001));
        lastUpdated = DAPPS_STAKING.read_current_era() - 1;
    }

    receive() external payable {}
}
