//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


interface IPool {
    function getVirtualPrice() external view returns (uint256);
    function getTokenBalance(uint8 index) external view returns (uint256);
    function getTokenIndex(address tokenAddress) external view returns (uint8 tokenIndex);
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
    function calc(address _user) external view returns (uint sum) {
        require(msg.sender == liquid || msg.sender == owner, "Only for Algem or owner");
        uint userLpBal = lp.balanceOf(_user);
        uint userGaugeBal = gauge.balanceOf(_user);
        uint virtualPrice = pool.getVirtualPrice() / 10**18;
        uint nTokensInPool = pool.getTokenBalance(idxNtoken);
        uint tokensInPool = pool.getTokenBalance(idxToken);

        sum = ((userLpBal + userGaugeBal) * virtualPrice) * nTokensInPool / (tokensInPool + nTokensInPool);
    }

}

// pool 0x35F1Dd344978A57612d08e8E017B9c99AAE4cFd6
// lp 0x5a9B56f64f0AA1282EEB299A09A9D284bE6dE26a
// gauge 0x528cF43a18e088B93367c12Be0663D42f7a93A2F
// nToken 0xa51599eC60eA10F6f24b639daC42C25Fa02c9247
// token 0x04efa209F9e74E612a529c393Cf9F1141E696F06

// liquid 0x12dDBa076ae4A95C9c772DD258781Ea2Dfb44e96

// deployed SiriusHandler 0xB1f0713C3026C53ccD37808DcEbDD0d936c632bD
