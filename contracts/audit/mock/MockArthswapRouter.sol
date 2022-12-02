//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./MockERC20.sol";
import "./libraries/Math.sol";

contract MockArthswapRouter {
    MockERC20 public lp;
    MockERC20 public nastr;

    uint256 public reservesN;
    uint256 public reservesT;

    constructor(MockERC20 _lp, MockERC20 _nastr) {
        lp = _lp;
        nastr = _nastr;
        reservesN = 100 ether;
        reservesT = 100 ether;
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (
            uint amountToken,
            uint amountETH,
            uint liquidity
        )
    {   
        nastr.transferFrom(msg.sender, address(this), amountTokenDesired);
        liquidity = Math.sqrt(amountTokenDesired * msg.value);
        reservesN += uint112(amountTokenDesired);
        reservesT += uint112(msg.value);
        lp.mint(msg.sender, liquidity);
        return (amountToken, amountETH, liquidity);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        uint256 totalLiquidity = lp.totalSupply();
        amountToken = reservesN * liquidity / totalLiquidity;
        amountETH = reservesT * liquidity / totalLiquidity;

        reservesN -= uint112(amountToken);
        reservesT -= uint112(amountETH);

        lp.transferFrom(msg.sender, address(this), liquidity);
        lp.burn(address(this), liquidity);
        nastr.transfer(msg.sender, amountToken);
        payable(msg.sender).transfer(amountETH);
    }

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB) {
        amountB = amountA * reserveB / reserveA;
    }
}
