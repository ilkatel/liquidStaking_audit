// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// @notice nASTR token contract interface
interface nASTRInterface {
  function mintNote(address to, uint256 amount) external;
  function burnNote(address account, uint256 amount) external;
  function snapshot() external;
  function pause() external;
  function unpause() external;
}
