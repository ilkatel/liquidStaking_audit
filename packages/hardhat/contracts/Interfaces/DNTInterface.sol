// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// @notice DNT token contract interface
interface DNTInterface {
  function        mintNote(address to, uint256 amount) external;
  function        burnNote(address account, uint256 amount) external;
  function        snapshot() external;
  function        pause() external;
  function        unpause() external;
  function        transferOwnership(address to) external;
}
