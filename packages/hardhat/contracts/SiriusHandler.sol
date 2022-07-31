//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface IPool {
    function getVirtualPrice() external view returns (uint256);
    function getTokenBalance(uint8 index) external view returns (uint256);
    function getTokenIndex(address tokenAddress) external view returns (uint8 tokenIndex);
    function getToken(uint8 index) external view returns (address);
}

interface IToken {
    function balanceOf(address _user) external view returns (uint);
}

contract SiriusHandler {

    IPool public pool;
    IToken public lp;
    IToken public gauge;
    address public nToken;
    address public token;
    uint8 public idxNtoken;
    uint8 public idxToken;
    address private liquid;
    address public owner;

    constructor(
        IPool _pool,
        IToken _lp,
        IToken _gauge,
        address _nToken,
        address _token,
        address _liquid
    ) {
        pool = _pool;
        lp = _lp;
        gauge = _gauge;
        nToken = _nToken;
        token = _token;
        idxNtoken = pool.getTokenIndex(nToken);
        idxToken = pool.getTokenIndex(token);
        owner = msg.sender;
        liquid = _liquid;
    }

    // @notice calculates nTokens share for user in pool
    function calc(address _user) external view returns (uint) {
        require(msg.sender == liquid || msg.sender == owner, "Only for Algem or owner");
        require(_user != address(0), "Zero address error");
        uint sum;
        uint userLpBal = lp.balanceOf(_user);
        uint userGaugeBal = gauge.balanceOf(_user);
        uint virtualPrice = pool.getVirtualPrice() / 10**18;
        uint nTokensInPool = pool.getTokenBalance(idxNtoken);
        uint tokensInPool = pool.getTokenBalance(idxToken);
        if (nTokensInPool == 0 || tokensInPool == 0) {
            return 0;
        }
        sum = ((userLpBal + userGaugeBal) * virtualPrice) * nTokensInPool / (tokensInPool + nTokensInPool);
        return sum;
    }

}
