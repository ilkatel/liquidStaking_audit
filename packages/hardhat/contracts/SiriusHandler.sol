//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface IPool {
    function getVirtualPrice() external view returns (uint256);
    function getTokenBalance(uint8 index) external view returns (uint256);
    function getTokenIndex(address tokenAddress) external view returns (uint8 tokenIndex);
}

interface ILpToken {
    function balanceOf(address _user) external view returns (uint);
}

interface IGauge {
    function balanceOf(address _user) external view returns (uint);
}

contract SiriusHandler {

    IPool public pool;
    ILpToken public lp;
    IGauge public gauge;
    address public nToken;
    address public token;
    uint8 public idxNtoken;
    uint8 public idxToken;

    constructor(
        IPool _pool,
        ILpToken _lp,
        IGauge _gauge,
        address _nToken,
        address _token
    ) {
        pool = _pool;
        lp = _lp;
        gauge = _gauge;
        nToken = _nToken;
        token = _token;
        idxNtoken = pool.getTokenIndex(nToken);
        idxToken = pool.getTokenIndex(token);
    }

    // @notice calculates nTokens share for user in pool
    function calc(address _user) external view returns (uint sum) {
        uint userLpBal = lp.balanceOf(_user);
        uint userGaugeBal = gauge.balanceOf(_user);
        uint virtualPrice = pool.getVirtualPrice();
        uint nTokensInPool = pool.getTokenBalance(idxNtoken);
        uint tokensInPool = pool.getTokenBalance(idxToken);
        uint percentage = nTokensInPool * 10**18 / (tokensInPool + nTokensInPool);

        sum = ((userLpBal + userGaugeBal) * virtualPrice) * percentage / 10**18;
    }

}
