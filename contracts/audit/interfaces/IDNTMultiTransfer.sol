// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// @notice DNT token contract interface to multiTrnsfer function
interface IDNTMultiTransfer {
  function transferFromUtilities(address to, uint256[] memory amounts, string[] memory utilities) external;
}
