//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface ISiriusPool {
    function addLiquidity(uint256[] calldata amounts, uint256 minToMint, uint256 deadline) external payable returns (uint256);
    function removeLiquidity(uint256 amount, uint256[] memory minAmounts,uint256 deadline) external returns (uint256[] memory);
    function removeLiquidityImbalance(uint256[] memory amounts, uint256 maxBurnAmount, uint256 deadline) external returns (uint256);
    function removeLiquidityOneCoin(uint256 tokenAmount, uint256 tokenIndex, uint256 minAmount, address receiver) external;
    function getA() external view returns (uint8 A);
    function getVirtualPrice() external view returns (uint);
    function getTokenBalance(uint8) external view returns (uint);
    function getTokenIndex(address tokenAddress) external view returns (uint8 tokenIndex);
    function calculateTokenAmount(uint256[] calldata amounts, bool deposit) external view returns (uint256);
    function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[] memory);
}
