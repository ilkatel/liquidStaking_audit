// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// @notice DNT token contract interface
interface IDNT {
  function        mintNote(address to, uint256 amount) external;
  function        burnNote(address account, uint256 amount) external;
  function        snapshot() external;
  function        pause() external;
  function        unpause() external;
  function        transferOwnership(address to) external;
  function        balanceOf(address account) external returns(uint256);
}
