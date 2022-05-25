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

        await distrContract.addDnt("nASTR", nASTRContract.address);

        LSContract = await LSfactory.deploy(ethers.constants.AddressZero, ethers.BigNumber.from(0));
        await distrContract.addUtility("LS");
        await distrContract.addManager(LSContract.address);
    });

    // @notice set staking timeframes etc.
    describe("Staking settings", function () {
        const t1 = 3600 * 24 * 7;
        const t2 = 3600 * 24 * 14;
        const t3 = 3600 * 24 * 21;
        const t4 = 3600 * 24 * 24;
        const t5 = 3600 * 24 * 28;

        it("Should add 3 staking terms", async function () {
            expect(
                await LSContract.addTerm(t1) // week
            ).to.satisfy;
            expect(
                await LSContract.tfs(1)
            ).to.be.equal(t1);

            expect(
                await LSContract.addTerm(t2) // 2 weeks
            ).to.satisfy;
            expect(
                await LSContract.tfs(2)
            ).to.be.equal(t2);

            expect(
                await LSContract.addTerm(t3) // 3 weeks
            ).to.satisfy;
            expect(
                await LSContract.tfs(3)
            ).to.be.equal(t3);

            expect(
                await LSContract.addTerm(t4) // 4 weeks!?
            ).to.satisfy;
            expect(
                await LSContract.tfs(4)
            ).to.be.equal(t4);

            expect(
                await LSContract.changeTerm(4, t5) // now really
            ).to.satisfy;
            expect(
                await LSContract.tfs(4)
            ).to.be.equal(t5);
        });

        it("Should set distributor", async function () {
            expect(
                await LSContract.setDistr(distrContract.address)
            ).to.satisfy;
            
            expect(
                await LSContract.distrAddr()
            ).to.be.equal(distrContract.address);
        });

        it("Should set min staking value", async function () { 
            expect(
                await LSContract.setMinStake(minStaking)
            ).to.satisfy;
            expect(
                await LSContract.minStake()
            ).to.be.equal(minStaking);
        });
    });

    describe("Staking", function () {
        const t1 = ethers.BigNumber.from(3600 * 24 * 7);
        const t2 = ethers.BigNumber.from(3600 * 24 * 14);
        const t3 = ethers.BigNumber.from(3600 * 24 * 21);
        it("Should stake some tokens", async function () {
            expect( // stake 1000 for 1 week
                await LSContract.connect(u1).stake(1, { value: val1 })
            ).to.emit(LSContract, "Staked").withArgs(
                u1.address, val1, t1
            );
            expect( // check stake balance
                (await LSContract.stakes(u1.address)).totalBalance
            ).to.be.equal(val1);

            expect( // stake 2000 for 2 week
                await LSContract.connect(u2).stake(2, { value: val2 })
            ).to.emit(LSContract, "Staked").withArgs(
                u2.address, val2, t2
            );
            expect( // check stake balance
                (await LSContract.stakes(u2.address)).totalBalance
            ).to.be.equal(val2);

            expect( // stake 3000 for 3 week
                await LSContract.connect(u3).stake(3, { value: val3 })
            ).to.emit(LSContract, "Staked").withArgs(
                u3.address, val3, t3
            );
            expect( // check stake balance
                (await LSContract.stakes(u3.address)).totalBalance
            ).to.be.equal(val3);
        });

        it("Should claim DNTs", async function () {
            /*
             * 1st claim immedeate
             * 2nd claim after 1 week (mid-term)
             * 3d  claim after 3 week (end-term)
             */
            const c1 = await LSContract.nowClaimable(u1.address);
            expect(
                await LSContract.connect(u1).claim(c1)
            ).to.emit(LSContract, "Claimed").withArgs(
                u1.address, c1
            );
            expect(
                await nASTRContract.balanceOf(u1.address)
            ).to.be.equal(c1);

            // @dev +7 days
            await network.provider.send("evm_increaseTime", [3600 * 24 * 7]);
            await network.provider.send("evm_mine");

            const c2 = await LSContract.nowClaimable(u2.address);
            expect(
                await LSContract.connect(u2).claim(c2)
            ).to.emit(LSContract, "Claimed").withArgs(
                u2.address, c2
            );
            expect(
                await nASTRContract.balanceOf(u2.address)
            ).to.be.equal(c2);

            // @dev + 21 days
            await network.provider.send("evm_increaseTime", [3600 * 24 * 14]);
            await network.provider.send("evm_mine");

            const c3 = await LSContract.nowClaimable(u3.address);
            expect(
                await LSContract.connect(u3).claim(c3)
            ).to.emit(LSContract, "Claimed").withArgs(
                u3.address, c3
            );
            expect(
                await nASTRContract.balanceOf(u3.address)
            ).to.be.equal(c3);
        });

        it("Should redeem native tokens", async function () {
            const b1 = await nASTRContract.balanceOf(u1.address);
            const b2 = await nASTRContract.balanceOf(u2.address);
            const b3 = await nASTRContract.balanceOf(u3.address);

            expect(
                await LSContract.connect(u1).redeem(b1)
            ).to.emit(LSContract, "Redeemed").withArgs(
                u1.address, b1
            );
            expect(
                await nASTRContract.balanceOf(u1.address)
            ).to.be.equal(0);

            expect(
                await LSContract.connect(u2).redeem(b2)
            ).to.emit(LSContract, "Redeemed").withArgs(
                u2.address, b2
            );
            expect(
                await nASTRContract.balanceOf(u2.address)
            ).to.be.equal(0);

            expect(
                await LSContract.connect(u3).redeem(b3)
            ).to.emit(LSContract, "Redeemed").withArgs(
                u3.address, b3
            );
            expect(
                await nASTRContract.balanceOf(u3.address)
            ).to.be.equal(0);
        });

    });
});

}