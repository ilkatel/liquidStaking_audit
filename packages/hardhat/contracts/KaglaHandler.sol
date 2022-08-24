// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


interface IPool {
    function get_virtual_price() external view returns (uint);
}

interface IToken {
    function balanceOf(address) external view returns (uint);
}

contract KaglaHandler {

    IPool public pool = IPool(0x327d5322242B5558bebA1dfb9C02A9Da63551D67);
    address public token = 0xAeaaf0e2c81Af264101B9129C00F4440cCF0F720;
    IToken public gauge = IToken(0xEC1BD689f7576E912348D50aE3F10F4cA5489384);
    IToken public lp = IToken(0x847f0Fd7e3A234E7321D01fF2347E4501eA89cF1);
    IToken public nToken = IToken(0xE511ED88575C57767BAfb72BfD10775413E3F2b0);
    uint public virtualPrice = pool.get_virtual_price() / 10**18;
    address public liquid = 0x70d264472327B67898c919809A9dc4759B6c0f27;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function calc(address user) public view returns (uint sum) {
        require(msg.sender == liquid || msg.sender == owner, "Only for Algem or owner");
        require(user != address(0), "Zero address error");
        uint userLpBal = lp.balanceOf(user);
        uint userGaugeBal = gauge.balanceOf(user);
        uint nTokensInPool = nToken.balanceOf(address(pool));
        uint tokensInPool = address(pool).balance;

        sum = ((userLpBal + userGaugeBal) * virtualPrice) * nTokensInPool / (tokensInPool + nTokensInPool);
    }
}
