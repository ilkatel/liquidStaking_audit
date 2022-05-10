const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

describe("Liquid staking", function () {

    let owner;
    let minStaking = ethers.utils.parseEther("1000"); // minimum staking value
    let nASTRaddr = ""; // nASTR contract address
    /**
	  * @param		[address] _token => nASTR token address
	  * @param		[uint256] _min => minimum ASTR amount to stake
	  * constructor(address _token, uint256 _min)
      */
    let LScontract;

    before(() => {
        [owner] = await ethers.getSigners();

        const LSfactory = await ethers.getContractFactory("LiquidStaking");

        LScontract = await LSfactory.deploy(nASTRaddr, minStaking);
    });

    describe("", function () {
        it("", async function () {

        });
    });
});