//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./MockArthswapRouter.sol";

contract MockArthswapPair {
    MockArthswapRouter public pool;
    MockERC20 public lp;

    constructor(MockArthswapRouter _pool, MockERC20 _lp) {
        pool = _pool;
        lp = _lp;
    }
    
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        reserve0 = uint112(pool.reservesT());
        reserve1 = uint112(pool.reservesN());
        blockTimestampLast = uint32(block.timestamp);
    }

    function totalSupply() public view returns (uint256) {
        return lp.totalSupply();
    }
}
