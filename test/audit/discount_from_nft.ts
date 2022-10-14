import {default as cfg} from "../../config/audit/cfg.json";
import {default as consts} from "../../config/audit/consts.json";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";
import { DappsStaking } from "../../typechain-types/contracts/audit/interfaces";
import { MockDapp } from "../../typechain-types/contracts/audit/mock/MockDapp";

import { LiquidStaking, NASTR, NDistributor, NFTDistributor, AdaptersDistributor, Algem721 } from "../../typechain-types/contracts/audit";

let signer: SignerWithAddress;  // 0xDE47D123fE04f164AFc64034B9D5F8790Ace7a9a
let acc: SignerWithAddress;  // 0x545598Fe8f589Cb31d6c6C6FbeDE58C54DeE6638
let accs: SignerWithAddress[];

let liquidStaking: LiquidStaking;
let nASTR: NASTR;
let distr: NDistributor;
let dappsStaking: DappsStaking;
let mockDapp: MockDapp;
let mockDapp2: MockDapp;
let mockDapp3: MockDapp;
let nftDistr: NFTDistributor;
let adaptersDistr: AdaptersDistributor;
let nft: Algem721;
let nft2: Algem721;
let nft3: Algem721;

let uNft: Algem721;
let uNft2: Algem721;
let uNft3: Algem721;

const defaultComission = 9;
const comission1 = 7;
const comission2 = 5;

const uComission1 = 8;
const uComission2 = 5;
const uComission3 = 3;

const all = 100;
const fee = 1;  // unstaking fee

let amount: BigNumber = ethers.utils.parseEther("1000");

let unbPeriod: BigNumber;

async function era() {
    return await liquidStaking.currentEra();
}

// approximately equal function
function aeq(x: BigNumber, y: BigNumber) {
    const _x = (x.toString()).slice(0, 7);
    const _y = (y.toString()).slice(0, 7);
    console.log(x, y);
    console.log(_x, _y);
    return _x == _y;
}

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
    console.log('Signer dnt in uUtil3', await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil3, consts.dnt));
    console.log('Acc dnt in util     ', await distr.getUserDntBalanceInUtil(acc.address, consts.util, consts.dnt));
    console.log('Acc dnt in util2    ', await distr.getUserDntBalanceInUtil(acc.address, consts.util2, consts.dnt));
    console.log('Preview signer rews ', await liquidStaking.previewUserRewards(consts.util, signer.address));
    console.log('Preview signer uRew3', await liquidStaking.previewUserRewards(consts.uUtil3, signer.address));
    console.log('Preview acc rews    ', await liquidStaking.previewUserRewards(consts.util, acc.address));
    console.log('Preview acc rews2   ', await liquidStaking.previewUserRewards(consts.util2, acc.address));
    let p1 = await liquidStaking.rewardPool();
    console.log('Rewards pool        ', p1);
    let p2 = await liquidStaking.unbondedPool();
    console.log('Unbonded pool       ', p2);
    let p3 = await liquidStaking.totalRevenue();
    console.log('Revenue pool        ', p3);
    let p4 = await liquidStaking.unstakingPool();
    console.log('Unstaking pool      ', p4);
    console.log('summ                ', p1.add(p3).add(p4));
    console.log('LiqStaking balance  ', await ethers.provider.getBalance(liquidStaking.address));
    console.log('last era total bal  ', await liquidStaking.lastEraTotalBalance());
    console.log('era buffer          ', await liquidStaking.eraBuffer(0), await liquidStaking.eraBuffer(1));
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

        liquidStaking = await ethers.getContractAt('contracts/audit/LiquidStaking.sol:LiquidStaking', cfg.liquidStaking, signer);
        dappsStaking = await ethers.getContractAt('contracts/audit/interfaces/DappsStaking.sol:DappsStaking', cfg.dappsStaking, signer);
        nASTR = await ethers.getContractAt('contracts/audit/NASTR.sol:NASTR', cfg.nASTR, signer);
        distr = await ethers.getContractAt('contracts/audit/NDistributor.sol:NDistributor', cfg.distr, signer);
        mockDapp = await ethers.getContractAt('contracts/audit/mock/mockDapp.sol:mockDapp', cfg.mockDapp, signer);
        nftDistr = await ethers.getContractAt('contracts/audit/NFTDistributor.sol:NFTDistributor', cfg.nftDistr, signer);
        adaptersDistr = await ethers.getContractAt('contracts/audit/AdaptersDistributor.sol:AdaptersDistributor', cfg.adapterDistr, signer);
        nft = await ethers.getContractAt('contracts/audit/Algem721.sol:Algem721', cfg.nft, signer);
        nft2 = await ethers.getContractAt('contracts/audit/Algem721.sol:Algem721', cfg.nft2, signer);
        uNft = await ethers.getContractAt('contracts/audit/Algem721.sol:Algem721', cfg.unft, signer);
        uNft3 = await ethers.getContractAt('contracts/audit/Algem721.sol:Algem721', cfg.unft2, signer);

        console.log(await nft.utilName());
        console.log(await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt));
        console.log(await distr.utilityDB(0));
        console.log(await distr.utilityDB(1));
        console.log(await distr.utilityDB(2));
        console.log(await distr.utilityDB(3));

        await nextEra();
    });

    it("print DS info", async function () {
        unbPeriod = await dappsStaking.read_unbonding_period();
        console.log('unb period:  ', unbPeriod);
        console.log('current era: ', await dappsStaking.read_current_era());
    });

    it("stake", async function () {
        await info();

        let tx = await liquidStaking.connect(signer).stake([consts.util], [amount.div(2)], {value: amount.div(2)});
        await tx.wait();

        tx = await liquidStaking.setting();
        await tx.wait();

        tx = await liquidStaking.connect(acc).stake([consts.util], [amount.div(2)], {value: amount.div(2)});
        await tx.wait();

        tx = await nft.mint(acc.address);
        await tx.wait();

        await info();
        await nextEra();
        
        tx = await liquidStaking.connect(signer).stake([consts.util], [amount.div(2)], {value: amount.div(2)});
        await tx.wait();
        tx = await liquidStaking.connect(acc).stake([consts.util], [amount.div(2)], {value: amount.div(2)});
        await tx.wait();

        await info();

    });

    it("test harvest (different commissions)", async function () {
        await nextEra();

        let tx = await liquidStaking.sync(await era());
        await tx.wait();
        tx = await liquidStaking.syncHarvest(signer.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();
        
        await info();
        await nextEra();

        tx = await liquidStaking.sync(await era());
        await tx.wait();
        tx = await liquidStaking.syncHarvest(signer.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();

        await info();

        let previewRewardsSigner = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let previewRewardsAcc = await liquidStaking.previewUserRewards(consts.util, acc.address);
        
        console.log(previewRewardsSigner);
        console.log(previewRewardsAcc);

        expect(previewRewardsSigner).not.be.eq(previewRewardsAcc);
        expect(true).to.be.eq(aeq(previewRewardsSigner.div(all - defaultComission - fee), previewRewardsAcc.div(all - comission1 - fee)));
    });

    it("stake in different dapp && claim all rewards", async function () {
        await info();

        let tx = await nft2.mint(acc.address);
        await tx.wait();
        tx = await liquidStaking.connect(acc).stake([consts.util2], [amount], {value: amount});
        await tx.wait();

        await info();

        tx = await uNft3.mint(signer.address);
        await tx.wait();
        tx = await liquidStaking.connect(signer).stake([consts.uUtil3], [amount], {value: amount});
        await tx.wait();

        tx = await liquidStaking.syncHarvest(signer.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();

        await info();

        await nextEra();
        await nextEra();    

        await info();

        tx = await liquidStaking.sync(await era());
        await tx.wait();
        tx = await liquidStaking.syncHarvest(signer.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(signer.address, [consts.uUtil3]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util2]);
        await tx.wait();

        await info();
        let rewardsBefore = await liquidStaking.rewardPool();

        let previewRewardsSigner1 = await liquidStaking.previewUserRewards(consts.util, signer.address);
        let previewRewardsAcc1 = await liquidStaking.previewUserRewards(consts.util, acc.address);
        let previewRewardsSigner2 = await liquidStaking.previewUserRewards(consts.uUtil3, signer.address);
        let previewRewardsAcc2 = await liquidStaking.previewUserRewards(consts.util2, acc.address);

        let rewardsSum = previewRewardsAcc2.add(previewRewardsSigner2).add(previewRewardsAcc1).add(previewRewardsSigner1);

        console.log(previewRewardsSigner1, previewRewardsSigner2);
        console.log(previewRewardsAcc1, previewRewardsAcc2);
        console.log(rewardsSum);
        console.log(rewardsBefore);
        expect(rewardsBefore).to.be.gte(rewardsSum);

        await nextEra();
        await info();

        tx = await liquidStaking.connect(signer).claimAll();
        await tx.wait();
        tx = await liquidStaking.connect(acc).claimAll();
        await tx.wait();

        let rewardsAfter = await liquidStaking.rewardPool();

        previewRewardsSigner1 = await liquidStaking.previewUserRewards(consts.util, signer.address);
        previewRewardsAcc1 = await liquidStaking.previewUserRewards(consts.util, acc.address);
        previewRewardsSigner2 = await liquidStaking.previewUserRewards(consts.uUtil3, signer.address);
        previewRewardsAcc2 = await liquidStaking.previewUserRewards(consts.util2, acc.address);
        
        await info();

        console.log(rewardsAfter);
        expect(ethers.BigNumber.from(0)).to.be.eq(previewRewardsAcc2.add(previewRewardsSigner2).add(previewRewardsAcc1).add(previewRewardsSigner1));

        await nextEra();

        tx = await liquidStaking.sync(await era());
        await tx.wait();
        tx = await liquidStaking.syncHarvest(signer.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(signer.address, [consts.uUtil3]);
        await tx.wait();
        tx = await liquidStaking.syncHarvest(acc.address, [consts.util2]);
        await tx.wait();
        
        await info();
    });
}); 