import {default as cfg} from "../../config/common/cfg.json";
import {default as consts} from "../../config/common/consts.json";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";
import { LiquidStaking1_5, NASTR1_5, NDistributor1_5 } from "../../typechain-types/contracts/common";
import { DappsStaking } from "../../typechain-types/contracts/common/interfaces";
import { MockDapp } from "../../typechain-types/contracts/common/mock/MockDapp";


let signer: SignerWithAddress;  // 0xDE47D123fE04f164AFc64034B9D5F8790Ace7a9a
let acc: SignerWithAddress;  // 0x545598Fe8f589Cb31d6c6C6FbeDE58C54DeE6638
let accs: SignerWithAddress[];

let liquidStaking: LiquidStaking1_5;
let nASTR: NASTR1_5;
let distr: NDistributor1_5;
let dappsStaking: DappsStaking;
let mockDapp: MockDapp;

const zeroHash = ethers.constants.HashZero;
const zeroAddress = ethers.constants.AddressZero;

let amount: BigNumber = ethers.utils.parseEther("1000");
let ofset: BigNumber = BigNumber.from("1000000000");

let rewPerEra: BigNumber;
let unbPeriod: BigNumber;

const unknownUtil = "unk";

async function sleep(eras: number) {
    await new Promise(f => setTimeout(f, eras*120*1000));
}

async function era() {
    return await liquidStaking.currentEra();
}

function _ofset(x: BigNumber) {
    return x.div(ofset).mul(ofset);
}

// work
async function nextEra() {
    const _era = (await era()).add(1);
    while (true) {
        await new Promise(f => setTimeout(f, 3000));
        if ((await era()).gte(_era)) {
            console.log(' > next era');
            return;
        }
    }
}

async function info() {
    console.log('-------------------------------------');
    console.log('Current era         ', await era());
    console.log('Total dnt           ', await distr.totalDnt(consts.dnt));
    console.log('Total dnt in util   ', await distr.totalDntInUtil(consts.util));
    console.log('Total dnt in util2  ', await distr.totalDntInUtil(consts.util2));
    console.log('Signer dnt in util  ', await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt));
    console.log('Signer dnt in util2 ', await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt));
    console.log('Acc dnt in util     ', await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt));
    console.log('Acc dnt in util2    ', await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt));
    console.log('Preview signer rews ', await liquidStaking.previewUserRewards(consts.util, signer.address));
    console.log('Preview signer rews2', await liquidStaking.previewUserRewards(consts.util2, signer.address));
    console.log('Preview acc rews    ', await liquidStaking.previewUserRewards(consts.util, acc.address));
    console.log('Preview acc rews2   ', await liquidStaking.previewUserRewards(consts.util2, acc.address));
    console.log('Rewards pool        ', await liquidStaking.rewardPool());
    console.log('Unbonded pool       ', await liquidStaking.unbondedPool());
    console.log('Unstaking pool      ', await liquidStaking.unstakingPool());
    console.log('LiqStaking balance  ', await ethers.provider.getBalance(liquidStaking.address));
    console.log('-------------------------------------');
}

describe("Algem app", function () {
    before(async function () {
        accs = await ethers.getSigners();   
        signer = accs[0];
        acc = accs[1];

        console.log('signer:  ', signer.address);
        console.log('balance: ', await signer.getBalance());
        console.log('--------------------');
        console.log('acc:  ', acc.address);
        console.log('balance: ', await acc.getBalance());

        liquidStaking = await ethers.getContractAt('LiquidStaking1_5', cfg.liquidStaking, signer);
        dappsStaking = await ethers.getContractAt('contracts/common/interfaces/DappsStaking.sol:DappsStaking', cfg.dappsStaking, signer);
        nASTR = await ethers.getContractAt('NASTR1_5', cfg.nASTR, signer);
        distr = await ethers.getContractAt('NDistributor1_5', cfg.distr, signer);
        mockDapp = await ethers.getContractAt('contracts/common/mock/mockDapp.sol:mockDapp', cfg.mockDapp, signer);

        await nextEra();
    });

    it("print DS info", async function () {
        unbPeriod = await dappsStaking.read_unbonding_period();
        console.log('unb period:  ', unbPeriod);
        console.log('current era: ', await dappsStaking.read_current_era());
    });

    it("stake test", async function () {
        let signerRewardsBefore = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let accRewardsBefore = await liquidStaking.previewUserRewards(consts.util, acc.address);

        expect(signerRewardsBefore).to.be.eq(0);
        expect(accRewardsBefore).to.be.eq(0);

        await nextEra();
        console.log('Before staking:');
        await info();

        let tx = await liquidStaking.connect(signer).stake([consts.util], [amount], {value: amount});
        await tx.wait();

        tx = await liquidStaking.setting();
        await tx.wait();

        tx = await liquidStaking.connect(acc).stake([consts.util], [amount], {value: amount});
        await tx.wait();

        // signer balance = amount
        // acc balance = amount

        await expect(liquidStaking.stake([unknownUtil], [amount], {value: amount})).to.be.rejectedWith("Dapp not active");
        await expect(liquidStaking.stake([consts.util], [0], {value: amount})).to.be.rejectedWith("Not enough stake amount");
        await expect(liquidStaking.stake([consts.util], [amount], {value: amount.div(2)})).to.be.rejectedWith("Incorrect value");

        console.log('After staking:');
        await info();
        await nextEra();
        tx = await liquidStaking.sync(await era());
        await tx.wait();

        let signerRewardsAfter = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let accRewardsAfter = await liquidStaking.previewUserRewards(consts.util, acc.address);
        let rewardsBefore = await liquidStaking.rewardPool();

        expect(signerRewardsAfter).to.be.eq(0);
        expect(accRewardsAfter).to.be.eq(0);

        await info();
        await nextEra();
        tx = await liquidStaking.sync(await era());
        await tx.wait();

        signerRewardsAfter = await liquidStaking.previewUserRewards(consts.util, signer.address);
        accRewardsAfter = await liquidStaking.previewUserRewards(consts.util, acc.address);
        let rewardsAfter = await liquidStaking.rewardPool();
        let eraRewards = rewardsAfter.sub(rewardsBefore);

        await info();

        expect(signerRewardsAfter).not.be.eq(0);
        expect(accRewardsAfter).not.be.eq(0);

        console.log(signerRewardsAfter, accRewardsAfter);
        expect(signerRewardsAfter).to.be.eq(accRewardsAfter);

        rewPerEra = _ofset(eraRewards.div(2));
        expect(signerRewardsAfter).to.be.eq(rewPerEra);
    });

    it("transfer test", async function () {
        await expect(nASTR.transfer(acc.address, amount.mul(4))).to.be.rejected;

        let tx = await nASTR.transfer(acc.address, amount);
        await expect(() => tx)
            .changeTokenBalances(nASTR, [signer, acc], ['-' + amount.toString(), amount])

        // signer balance = 0
        // acc balance = 2*amount

        await info();

        expect(await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt)).to.be.eq(amount.mul(2));
        expect(await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt)).to.be.eq(0);

        await nextEra();
        tx = await liquidStaking.sync(await era());
        await tx.wait();

        let signerRewardsBefore = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let accRewardsBefore = await liquidStaking.previewUserRewards(consts.util, acc.address);

        await info();
        await nextEra();
        tx = await liquidStaking.sync(await era());
        await tx.wait();

        let signerRewardsAfter = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let accRewardsAfter = await liquidStaking.previewUserRewards(consts.util, acc.address);

        await info();

        console.log(rewPerEra);
        console.log(signerRewardsAfter.sub(signerRewardsBefore));
        expect(signerRewardsAfter.sub(signerRewardsBefore)).to.be.eq(0);
        console.log(accRewardsAfter.sub(accRewardsBefore));
        expect(accRewardsAfter.sub(accRewardsBefore)).to.be.eq(rewPerEra.mul(2));
    });

    it("harvest test", async function () {
        await nextEra();
        await info();

        await expect(liquidStaking.sync((await era()).add(1))).to.be.rejectedWith("Wrong era range");

        let tx = await liquidStaking.sync(await era());
        await tx.wait();

        let previewRewards = await liquidStaking.previewUserRewards(consts.util, acc.address);
        
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();

        let accRewards = await liquidStaking.getUserRewardsFromUtility(acc.address, consts.util);
        console.log(previewRewards, accRewards);
        expect(previewRewards).to.be.eq(accRewards);
    });

    it("claim test", async function () {
        await nextEra();
        let tx = await liquidStaking.sync(await era());
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();

        await info();

        await expect(liquidStaking.claim([consts.util3], [amount])).to.be.rejectedWith("Not enough rewards!");
        await expect(liquidStaking.claim([consts.util], [0])).to.be.rejectedWith("Nothing to cliam");

        let previewRewards = await liquidStaking.previewUserRewards(consts.util, acc.address);
        let toClaim = previewRewards.div(2);

        await info();
        
        tx = await liquidStaking.connect(acc).claim([consts.util], [toClaim]);
        await expect(() => tx).changeEtherBalance(acc, toClaim);

        await info();

        let previewRewardsAfter = await liquidStaking.previewUserRewards(consts.util, acc.address);
        expect(previewRewardsAfter).to.be.eq(previewRewards.sub(toClaim));
    });

    it("claimAll test", async function () {
        await nextEra();
        let tx = await liquidStaking.sync(await era());
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();

        await info();

        let previewRewards = await liquidStaking.previewUserRewards(consts.util, acc.address);

        tx = await liquidStaking.connect(acc).claimAll();
        await expect(() => tx).changeEtherBalance(acc, previewRewards);

        await info();

        expect(await liquidStaking.previewUserRewards(consts.util, acc.address)).to.be.eq(0);
    });

    // firstly register mockDapp
    it("multiTransfer test", async function () {
        let accUtilBalance = await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt);
        expect(await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt)).to.be.eq(0);

        let tx = await liquidStaking.connect(acc).stake([consts.util2], [amount], {value: amount});
        await expect(() => tx).changeTokenBalance(nASTR, acc, amount);

        // signer balance = 0
        // acc balance = 3*amount

        let accUtil2Balance = await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt);
        expect(accUtilBalance).to.be.eq(await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt));
        expect(accUtil2Balance).to.be.eq(amount);

        let signerUtilBalanceBefore = await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt);
        let signerUtil2BalanceBefore = await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt);

        await expect(nASTR.transferFromUtilities(acc.address, [amount.mul(3), amount.mul(3)], [consts.util, consts.util2])).to.be.rejected;
        await expect(() => nASTR.connect(acc).transferFromUtilities(signer.address, [amount, amount], [consts.util, consts.util2]))
            .changeTokenBalances(nASTR, [acc, signer], ['-' + (amount.mul(2).toString()), amount.mul(2)]);
        
        // signer balance = 2*amount
        // acc balance = amount

        expect(signerUtilBalanceBefore.add(amount)).to.be.eq(await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt));
        expect(signerUtil2BalanceBefore.add(amount)).to.be.eq(await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt))
        expect(await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt)).to.be.eq(accUtilBalance.sub(amount));
        expect(await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt)).to.be.eq(accUtil2Balance.sub(amount));
    });

    it("rewards from dapps tets", async function () {
        // signer util = amount
        // signer util2 = amount
        // acc util = amount
        // acc util2 = 0

        await nextEra();
        let tx = await liquidStaking.sync(await era());
        await tx.wait();
        await info();

        let rewardsBefore = await liquidStaking.rewardPool();
        let signerRewards1Before = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let signerRewards2Before = await liquidStaking.previewUserRewards(consts.util2, signer.address);
        let accRewards1Before = await liquidStaking.previewUserRewards(consts.util, acc.address);
        let accRewards2Before = await liquidStaking.previewUserRewards(consts.util2, acc.address);

        await nextEra();
        tx = await liquidStaking.sync(await era());
        await tx.wait();
        await info();

        let rewardsAfter = await liquidStaking.rewardPool();
        let signerRewards1After = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let signerRewards2After = await liquidStaking.previewUserRewards(consts.util2, signer.address);
        let accRewards1After = await liquidStaking.previewUserRewards(consts.util, acc.address);
        let accRewards2After = await liquidStaking.previewUserRewards(consts.util2, acc.address);

        let eraRewards = rewardsAfter.sub(rewardsBefore);
        let signerRewards1 = signerRewards1After.sub(signerRewards1Before);
        let signerRewards2 = signerRewards2After.sub(signerRewards2Before);
        let accRewards1 = accRewards1After.sub(accRewards1Before);
        let accRewards2 = accRewards2After.sub(accRewards2Before);

        console.log(eraRewards);    
        console.log(signerRewards1);
        console.log(signerRewards2);
        console.log(accRewards1);
        console.log(accRewards2);

        expect(signerRewards1).to.be.eq(_ofset(accRewards1));
        expect(accRewards2).to.be.eq(0);
        expect(signerRewards2).to.be.eq(signerRewards1);
        expect(eraRewards).to.be.gte(signerRewards1.add(signerRewards2).add(accRewards1).add(accRewards2));
    });

    it("default multiTransfer test", async function () {
        // signer util = amount
        // signer util2 = amount
        // acc util = amount
        // acc util2 = 0
        await info();

        let signerUtilBefore = await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt);
        let signerUtil2Before = await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt);
        let accUtilBefore = await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt);
        let accUtil2Before = await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt);

        let toTransfer = amount.mul(3).div(2);

        await expect(nASTR.transfer(acc.address, amount.mul(5))).to.be.rejected;

        let tx = await nASTR.connect(signer).transfer(acc.address, toTransfer);
        await expect(() => tx).changeTokenBalances(nASTR, [signer, acc], ["-" + toTransfer.toString(), toTransfer]);

        let signerUtilAfter = await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt);
        let signerUtil2After = await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt);
        let accUtilAfter = await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt);
        let accUtil2After = await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt);

        await info();

        expect(signerUtilAfter.add(signerUtil2After).add(accUtilAfter).add(accUtil2After))
            .to.be.eq(signerUtilBefore.add(signerUtil2Before).add(accUtilBefore).add(accUtil2Before));
        
        expect(true).to.be.eq(
            (signerUtilAfter.eq(0) && signerUtil2After.eq(amount.div(2)))
            || (signerUtil2After.eq(0) && signerUtilAfter.eq(amount.div(2)))
        );
    });

    it("unstake test", async function () {
        await nextEra();
        await info();

        let accUtilBefore = await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt);
        let accUtil2Before = await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt);

        const toUnstake = amount.div(2);

        await expect(liquidStaking.unstake([unknownUtil], [toUnstake], false)).to.be.rejectedWith("Unknown utility");
        await expect(liquidStaking.unstake([consts.util], [amount.mul(3)], false)).to.be.rejectedWith("Not enough nASTR in utility");
        await expect(liquidStaking.connect(acc).unstake([consts.util, consts.util2], [toUnstake, toUnstake], true)).to.be.rejectedWith("Unstaking pool drained!");

        let tx = await liquidStaking.connect(acc).unstake([consts.util, consts.util2], [toUnstake, toUnstake], false);
        await expect(() => tx).changeTokenBalance(nASTR, acc, "-" + amount.toString());
        
        await info();

        let accUtilAfter = await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt);
        let accUtil2After = await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt);

        expect(accUtilBefore.sub(toUnstake)).to.be.eq(accUtilAfter);
        expect(accUtil2Before.sub(toUnstake)).to.be.eq(accUtil2After);
    });

    it("withdraw test", async function () {
        for (let i = 0; i < 3; i++) {
            console.log(await era());

            await expect(liquidStaking.connect(acc).withdraw(0)).to.be.rejectedWith("Not enough eras passed!");

            await nextEra();
            await info();
        }

        console.log('next step');

        for (let i = 0; i < unbPeriod.toNumber(); i++) {
            console.log(await era());

            await expect(liquidStaking.connect(acc).withdraw(0)).to.be.rejectedWith("Unbonded pool drained!");

            let tx = await liquidStaking.sync(await era());
            await tx.wait();

            await nextEra();
            await info();
        }
        let tx = await liquidStaking.sync(await era());
        await tx.wait();

        await info();

        tx = await liquidStaking.connect(acc).withdraw(0);
        await expect(() => tx).changeEtherBalance(acc, amount.div(2));
        
        tx = await liquidStaking.connect(acc).withdraw(1);
        await expect(() => tx).changeEtherBalance(acc, amount.div(2));

        await expect(liquidStaking.connect(acc).withdraw(0)).to.be.rejectedWith("Withdrawal already claimed");

        await info();
    });

    it("unstake immediate test", async function () {
        const toUnstake = ethers.utils.parseEther("0.001");

        let tx = await liquidStaking.connect(acc).unstake([consts.util], [toUnstake], true);
        await expect(() => tx).changeEtherBalance(acc, toUnstake.sub(toUnstake.div(100)));
    });
});