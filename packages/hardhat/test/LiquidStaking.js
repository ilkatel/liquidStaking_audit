const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);

/*
 * @title:   Liquid staking test script
 * @author:  Daniil Rashin
*/

if (true) { // @dev change to 'false' to disable these tests

describe("Liquid staking", function () {

    // @notice some users
    let owner;
    let u1, u2, u3, u4, u5;

    // @notice Smart contracts
    let nASTRContract; // nASTR contract address
    let distrContract;
    let LSContract;

    // @notice BigNumbers
    const minStaking = ethers.utils.parseEther("1000"); // minimum staking value
    const val1 = ethers.utils.parseEther("1000");
    const val2 = ethers.utils.parseEther("2000");
    const val3 = ethers.utils.parseEther("3000");

    // @notice init contracts to be able to test
    before(async function () {

        // @notice assign users
        [owner, u1, u2, u3, u4, u5] = await ethers.getSigners();

        // @notice get contract factories
        const LSfactory = await ethers.getContractFactory("LiquidStaking");
        const DistrFactory = await ethers.getContractFactory("NDistributor");
        const nASTRFactory = await ethers.getContractFactory("NASTR");

        // @notice delpoy and set required data
        distrContract = await DistrFactory.deploy();
        nASTRContract = await nASTRFactory.deploy(distrContract.address);

        await distrContract.setAstrInterface(nASTRContract.address);

        LSContract = await LSfactory.deploy(distrContract.address, nASTRContract.address, minStaking);
        await distrContract.addUtility("LS");
        await distrContract.addDnt("nASTR");
    });

    // @notice set staking timeframes etc.
    describe("Staking settings", function () {
        it("Add some staking terms", async function () {
            expect(
                await LSContract.addTerm(3600 * 24 * 7) // week
            ).to.satisfy;
            expect(
                await LSContract.addTerm(3600 * 24 * 14) // 2 week
            ).to.satisfy;
            expect(
                await LSContract.addTerm(3600 * 24 * 21) // 3 week
            ).to.satisfy;
        });
    });

    describe("Staking", function () {
        it("Stake some tokens", async function () {
            expect(
                // stake 1000 for 1 week
                await LSContract.connect(u1).stake(0, { value: val1 })
            ).to.emit(LSContract, "Staked").withArgs(
                u1.address, 0, val1, 3600 * 24 * 7
            );
            expect( // check stake balance
                (await LSContract.stakes(0)).totalBalance
            ).to.be.equal(val1);

            expect(
                // stake 2000 for 2 week
                await LSContract.connect(u2).stake(1, { value: val2 })
            ).to.emit(LSContract, "Staked").withArgs(
                u2.address, 1, val2, 3600 * 24 * 14
            );
            expect( // check stake balance
                (await LSContract.stakes(1)).totalBalance
            ).to.be.equal(val2);

            expect(
                // stake 3000 for 3 week
                await LSContract.connect(u3).stake(2, { value: val3 })
            ).to.emit(LSContract, "Staked").withArgs(
                u3.address, 2, val3, 3600 * 24 * 21
            );
            expect( // check stake balance
                (await LSContract.stakes(2)).totalBalance
            ).to.be.equal(val3);
        });

        it("Claim DNTs", async function () {
            /*
             * 1st claim immedeate
             * 2nd claim after 1 week (mid-term)
             * 3d  claim after 3 week (end-term)
             */
            const c1 = await LSContract.nowClaimable(0);
            expect(
                await LSContract.connect(u1).claim(0, c1)
            ).to.emit(LSContract, "Claimed").withArgs(
                u1.address, 0, c1
            );
            expect( // check user's DNT balance
                await nASTRContract.balanceOf(u1.address)
            )

            // @dev +7 days
            await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
            await network.provider.send("evm_mine");

            const c2 = await LSContract.nowClaimable(1);
            expect(
                await LSContract.connect(u2).claim(1, c2)
            ).to.emit(LSContract, "Claimed").withArgs(
                u2.address, 1, c2
            );
            expect( // check user's DNT balance
                await nASTRContract.balanceOf(u2.address)
            ).to.be.equal(c2);

            // @dev + 21 days
            await network.provider.send("evm_increaseTime", [3600 * 24 * 14]);
            await network.provider.send("evm_mine");

            const c3 = await LSContract.nowClaimable(2);
            expect(
                await LSContract.connect(u3).claim(2, c3)
            ).to.emit(LSContract, "Claimed").withArgs(
                u3.address, 2, c3
            );
            expect( // check user's DNT balance
                await nASTRContract.balanceOf(u3.address)
            ).to.be.equal(c3);
        });
    });

    // @notice get native tokens in exhange of DNTs
    describe("Redeem", function () {
        it("Redeem ASTR", async function () {
            const b1 = await nASTRContract.balanceOf(u1.address);
            const b2 = await nASTRContract.balanceOf(u2.address);
            const b3 = await nASTRContract.balanceOf(u3.address);

            expect(
                await LSContract.connect(u1).redeem(0, b1)
            ).to.emit(LSContract, "Redeemed").withArgs(
                u1.address, 0, b1
            );
            expect(
                await nASTRContract.balanceOf(u1.address)
            ).to.be.equal("0");

            expect(
                await LSContract.connect(u2).redeem(1, b2)
            ).to.emit(LSContract, "Redeemed").withArgs(
                u2.address, 1, b2
            );
            expect(
                await nASTRContract.balanceOf(u2.address)
            ).to.be.equal("0");

            expect(
                await LSContract.connect(u3).redeem(2, b3)
            ).to.emit(LSContract, "Redeemed").withArgs(
                u3.address, 2, b3
            );
            expect(
                await nASTRContract.balanceOf(u3.address)
            ).to.be.equal("0");
        });
    });
});

}