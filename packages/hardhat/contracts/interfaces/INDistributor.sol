// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface INDistributor {
    function transferDnt(
        address,
        address,
        uint256,
        string memory,
        string memory
    ) external;
}
