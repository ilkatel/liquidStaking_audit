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
  function        balanceOfAt(address account, uint256 snapshotId) external returns (uint256);

  function        name() external returns (string memory);
  function        symbol() external returns (string memory);
  function        decimals() external returns (uint8);
  function        totalSupply() external returns (uint256);
  function        transfer(address _to, uint256 _value) external returns (bool success);
  function        transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
  function        approve(address _spender, uint256 _value) external returns (bool success);
  function        allowance(address _owner, address _spender) external returns (uint256 remaining);
}
