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

let stakedAmount: BigNumber;
let amount: BigNumber = ethers.utils.parseEther("1000");

let unbPeriod: BigNumber;

async function era() {
    return await liquidStaking.currentEra();
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

async function nftInfo(_era_: BigNumber, _util_: string) {
    console.log('-------------------------------------');
    console.log("balance in util: ", await distr.getUserDntBalanceInUtil(signer.address, _util_, consts.dnt));
    const r0 = await nftDistr.getUserNfts(signer.address);
    console.log("unique: ", r0[0], "default: ", r0[1]);
    const r1 = await nftDistr.getUserEraAmount(_util_, signer.address, _era_);
    console.log("era amount: ", r1[0], "is zero: ", r1[1], "updated: ", r1[2]);
    const r2 = await nftDistr.getUserInfo(signer.address);
    console.log("default comission: ", r2[0], "unique bal: ", r2[1], "uniquie coms: ", r2[2]);
    const r3 = await nftDistr.getEraAmount(_era_);
    console.log("era data: ", r3[0], "is zero: ", r3[1], "updated: ", r3[2]);
    const r4 = await nftDistr.getUtilAmount(_util_, _era_);
    console.log("total amount: ", r4[0], "total era amount: ", r4[1], "is zero: ", r4[2], "updated: ", r4[3]);
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

    it("Print DappsStaking info", async function () {
        unbPeriod = await dappsStaking.read_unbonding_period();
        console.log('unb period:  ', unbPeriod);
        console.log('current era: ', await dappsStaking.read_current_era());
    });

    it("staking in util before minting", async function () {
        let tx = await liquidStaking.connect(signer).stake([consts.util], [amount.div(2)], {value: amount.div(2)});
        await tx.wait();
        console.log("staked");

        try {
            let _tx = await liquidStaking.setting();
            await _tx.wait();
            console.log("setting");
        } catch(_) {}

        await nextEra();

        tx = await liquidStaking.connect(signer).stake([consts.util], [amount.div(4)], {value: amount.div(4)});
        await tx.wait();
        tx = await liquidStaking.connect(signer).stake([consts.util], [amount.div(4)], {value: amount.div(4)});
        await tx.wait();

        stakedAmount = amount;
    });

    it("minting default nft after staking", async function () {
        await nextEra();
        
        let signerNfts = await nftDistr.getUserNfts(signer.address);
        const uniquesBefore = signerNfts[0].length;
        const defaultsBefore = signerNfts[1].length;


        const _era_ = await era();
        await nftInfo(_era_, consts.util);

        let tx = await nft.mint(signer.address);
        await tx.wait();

        await nftInfo(_era_, consts.util);

        signerNfts = await nftDistr.getUserNfts(signer.address);
        expect(signerNfts[0].length).to.be.eq(uniquesBefore);
        expect(signerNfts[1].length).to.be.eq(defaultsBefore + 1);

        const result1 = await nftDistr.getUserEraAmount(consts.util, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.util, _era_);
        
        expect(result1[0]).to.be.eq(stakedAmount);
        expect(result1[1]).to.be.eq(false);

        expect(result2[0]).to.be.eq(comission1);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq(stakedAmount.mul(comission1));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(stakedAmount);
        expect(result4[1]).to.be.eq(stakedAmount);
        expect(result4[2]).to.be.eq(false);
    });

    it("remove default nft", async function () {
        await nextEra();
        
        let signerNfts = await nftDistr.getUserNfts(signer.address);
        const uniquesBefore = signerNfts[0].length;
        const defaultsBefore = signerNfts[1].length;
        
        const _era_ = await era();
        await nftInfo(_era_, consts.util);

        let tx = await nft.connect(signer).burn(await nft.tokenByIndex(0));
        await tx.wait();

        signerNfts = await nftDistr.getUserNfts(signer.address);

        await nftInfo(_era_, consts.util);

        expect(signerNfts[0].length).to.be.eq(uniquesBefore);
        expect(signerNfts[1].length).to.be.eq(defaultsBefore - 1);

        const result1 = await nftDistr.getUserEraAmount(consts.util, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.util, _era_);
        
        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(defaultComission);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(0);
        expect(result3[0][1]).to.be.eq(0);
        expect(result3[1]).to.be.eq(true);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);
    });

    it("mint default nft again", async function () {
        await nextEra();
        const _era_ = await era();
        await nftInfo(_era_, consts.util);

        let tx = await nft.mint(signer.address);
        await tx.wait();

        await nftInfo(_era_, consts.util);
    });

    it("minting default nft2 before staking", async function () {
        await nextEra();
        
        let signerNfts = await nftDistr.getUserNfts(signer.address);
        const uniquesBefore = signerNfts[0].length;
        const defaultsBefore = signerNfts[1].length;
        
        const _era_ = await era();
        await nftInfo(_era_, consts.util2);

        let tx = await nft2.mint(signer.address);
        await tx.wait();

        await nftInfo(_era_, consts.util2);

        signerNfts = await nftDistr.getUserNfts(signer.address);
        expect(signerNfts[0].length).to.be.eq(uniquesBefore);
        expect(signerNfts[1].length).to.be.eq(defaultsBefore + 1);

        const result1 = await nftDistr.getUserEraAmount(consts.util2, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.util2, _era_);
        
        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq(stakedAmount.mul(comission2));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);
    });

    it("mint uqinue nft1 (not change values)", async function () {
        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil1);

        let tx = await uNft.mint(signer.address);
        await tx.wait();

        await nftInfo(_era_, consts.uUtil1);

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil1, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil1, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq(stakedAmount.mul(comission2));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);
    });

    it("mint uqinue nft3 && stake (change values)", async function () {
        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil3);

        let tx = await uNft3.mint(signer.address);
        await tx.wait();

        tx = await liquidStaking.stake([consts.uUtil3], [amount], { value: amount });
        await tx.wait();
        stakedAmount = stakedAmount.add(amount);

        await nftInfo(_era_, consts.uUtil3);

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil3, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil3, _era_);

        expect(result1[0]).to.be.eq(amount);
        expect(result1[1]).to.be.eq(false);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount);
        expect(result2[2]).to.be.eq(amount.mul(uComission3));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount).mul(comission2)).add(amount.mul(uComission3)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(amount);
        expect(result4[1]).to.be.eq(amount);
        expect(result4[2]).to.be.eq(false);
    });

    it("stake with default nft2", async function () {
        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.util2);

        let tx = await liquidStaking.stake([consts.util2], [amount], { value: amount });
        await tx.wait();
        stakedAmount = stakedAmount.add(amount);

        await nftInfo(_era_, consts.util2);

        const result1 = await nftDistr.getUserEraAmount(consts.util2, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.util2, _era_);

        expect(result1[0]).to.be.eq(amount);
        expect(result1[1]).to.be.eq(false);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount);
        expect(result2[2]).to.be.eq(amount.mul(uComission3));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount).mul(comission2)).add(amount.mul(uComission3)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(amount);
        expect(result4[1]).to.be.eq(amount);
        expect(result4[2]).to.be.eq(false);
    });

    it("stake with unique nft1", async function () {
        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil1);

        let tx = await liquidStaking.stake([consts.uUtil1], [amount], { value: amount });
        await tx.wait();
        stakedAmount = stakedAmount.add(amount);

        await nftInfo(_era_, consts.uUtil1);

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil1, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil1, _era_);

        expect(result1[0]).to.be.eq(amount);
        expect(result1[1]).to.be.eq(false);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount.mul(2));
        expect(result2[2]).to.be.eq(amount.mul(uComission3).add(amount.mul(comission2)));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount).mul(comission2)).add(amount.mul(uComission3)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(amount);
        expect(result4[1]).to.be.eq(amount);
        expect(result4[2]).to.be.eq(false);
    }); 

    it("remove default nft2 | remains (1 default; 2 unique)", async function () {
        console.log("user util2 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt));

        await nextEra();

        let _era_ = await era();
        await nftInfo(_era_, consts.util2);

        let tx = await liquidStaking.unstake([consts.util2], [amount], false);
        await tx.wait();

        stakedAmount = stakedAmount.sub(amount);

        await nftInfo(_era_, consts.util2);

        let result1 = await nftDistr.getUserEraAmount(consts.util2, signer.address, _era_);
        let result2 = await nftDistr.getUserInfo(signer.address);
        let result3 = await nftDistr.getEraAmount(_era_);
        let result4 = await nftDistr.getUtilAmount(consts.util2, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount.mul(2));
        expect(result2[2]).to.be.eq(amount.mul(uComission3).add(amount.mul(comission2)));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount.mul(2)).mul(comission2)).add(amount.mul(uComission3)).add(amount.mul(comission2)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);

        await nextEra();

        _era_ = await era();
        await nftInfo(_era_, consts.util2);

        tx = await nft2.burn(await nft2.tokenByIndex(0));
        await tx.wait();

        await nftInfo(_era_, consts.util2);

        result1 = await nftDistr.getUserEraAmount(consts.util2, signer.address, _era_);
        result2 = await nftDistr.getUserInfo(signer.address);
        result3 = await nftDistr.getEraAmount(_era_);
        result4 = await nftDistr.getUtilAmount(consts.util2, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission1);
        expect(result2[1]).to.be.eq(amount.mul(2));
        expect(result2[2]).to.be.eq(amount.mul(uComission3).add(amount.mul(comission1)));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount).mul(comission1)).add(amount.mul(uComission3)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);


        // ---------------------------
        // get back
        // ---------------------------
        console.log("user util2 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt));

        tx = await liquidStaking.stake([consts.util2], [amount], { value: amount });
        await tx.wait();

        console.log("user util2 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt));

        tx = await nft2.mint(signer.address);
        await tx.wait();
        stakedAmount = stakedAmount.add(amount);
    });

    it("remove unique nft1 | remains (2 default; 1 unique)", async function () {
        console.log("user uUtil1 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil1, consts.dnt));

        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil1);

        let tx = await liquidStaking.unstake([consts.uUtil1], [amount], false);
        await tx.wait();
        stakedAmount = stakedAmount.sub(amount);

        await nftInfo(_era_, consts.uUtil1);

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil1, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil1, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount);
        expect(result2[2]).to.be.eq(amount.mul(uComission3));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount).mul(comission2)).add(amount.mul(uComission3)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);


        // ---------------------------
        // get back
        // ---------------------------
        console.log("user uUtil1 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil1, consts.dnt));

        tx = await liquidStaking.stake([consts.uUtil1], [amount], { value: amount });
        await tx.wait();

        console.log("user uUtil1 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil1, consts.dnt));

        stakedAmount = stakedAmount.add(amount);
    });

    it("remove unique nft3 | remains (2 default; 1 unique)", async function () {
        console.log("user uUtil3 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil3, consts.dnt));

        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil3);

        let tx = await liquidStaking.unstake([consts.uUtil3], [amount], false);
        await tx.wait();

        stakedAmount = stakedAmount.sub(amount);

        await nftInfo(_era_, consts.uUtil3);

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil3, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil3, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount);
        expect(result2[2]).to.be.eq(amount.mul(comission2));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq(stakedAmount.mul(comission2));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);


        // ---------------------------
        // get back
        // ---------------------------
        
        console.log("user uUtil3 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil3, consts.dnt));

        tx = await liquidStaking.stake([consts.uUtil3], [amount], { value: amount });
        await tx.wait();

        console.log("user uUtil3 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil3, consts.dnt));

        stakedAmount = stakedAmount.add(amount);
    });

    it("remove all default nft | remains (2 unique)", async function () {
        console.log("user util2 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.util2, consts.dnt));
        console.log("user util balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.util, consts.dnt));

        await nextEra();

        let _era_ = await era();
        await nftInfo(_era_, consts.util2);

        let tx = await liquidStaking.unstake([consts.util2], [amount], false);
        await tx.wait();

        await nftInfo(_era_, consts.util2);
        console.log('---------------------');
        await nftInfo(_era_, consts.util);

        tx = await liquidStaking.unstake([consts.util], [amount], false);
        await tx.wait();

        await nftInfo(_era_, consts.util);

        stakedAmount = stakedAmount.sub(amount.mul(2));
        
        let result1 = await nftDistr.getUserEraAmount(consts.util, signer.address, _era_);
        let result2 = await nftDistr.getUserInfo(signer.address);
        let result3 = await nftDistr.getEraAmount(_era_);
        let result4 = await nftDistr.getUtilAmount(consts.util, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(amount.mul(2));
        expect(result2[2]).to.be.eq(amount.mul(uComission3).add(amount.mul(uComission2)));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq(amount.mul(uComission3).add(amount.mul(uComission2)));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);

        await nextEra();
        _era_ = await era();
        await nftInfo(_era_, consts.util2)

        tx = await nft.burn(await nft.tokenByIndex(0));
        await tx.wait();
        tx = await nft2.burn(await nft2.tokenByIndex(0));
        await tx.wait();

        await nftInfo(_era_, consts.util2)

        result1 = await nftDistr.getUserEraAmount(consts.util, signer.address, _era_);
        result2 = await nftDistr.getUserInfo(signer.address);
        result3 = await nftDistr.getEraAmount(_era_);
        result4 = await nftDistr.getUtilAmount(consts.util, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(defaultComission);
        expect(result2[1]).to.be.eq(amount.mul(2));
        expect(result2[2]).to.be.eq(amount.mul(uComission3).add(amount.mul(uComission1)));
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq((stakedAmount.sub(amount.mul(2)).mul(defaultComission)).add(amount.mul(uComission3).add(amount.mul(uComission1))));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);


        // ---------------------------
        // get back
        // ---------------------------

        tx = await liquidStaking.stake([consts.util], [amount], { value: amount });
        await tx.wait();

        tx = await liquidStaking.stake([consts.util2], [amount], { value: amount });
        await tx.wait();

        tx = await nft.mint(signer.address);
        await tx.wait();
        tx = await nft2.mint(signer.address);
        await tx.wait();
        stakedAmount = stakedAmount.add(amount.mul(2));

        await nftInfo(_era_, consts.util2);
    });

    it("remove all unique nft | remains (2 default)", async function () {
        console.log("user uUtil1 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil1, consts.dnt));
        console.log("user uUtil3 balance in distr: ", await distr.getUserDntBalanceInUtil(signer.address, consts.uUtil3, consts.dnt));

        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil1);


        let tx = await liquidStaking.unstake([consts.uUtil1], [amount], false);
        await tx.wait();
        
        await nftInfo(_era_, consts.uUtil1);
        console.log('---------------------');
        await nftInfo(_era_, consts.uUtil3);

        tx = await liquidStaking.unstake([consts.uUtil3], [amount], false);
        await tx.wait();
        
        await nftInfo(_era_, consts.uUtil3);

        stakedAmount = stakedAmount.sub(amount.mul(2));

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil3, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil3, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(comission2);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(stakedAmount);
        expect(result3[0][1]).to.be.eq(stakedAmount.mul(comission2));
        expect(result3[1]).to.be.eq(false);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);
    });

    it("remove all default nft | remains (0 unique)", async function () {
        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.util2);
        
        let tx = await nft2.burn(await nft2.tokenByIndex(0));
        await tx.wait();

        await nftInfo(_era_, consts.util2);
        console.log('---------------------');
        await nftInfo(_era_, consts.util);

        tx = await nft.burn(await nft.tokenByIndex(0));
        await tx.wait();

        await nftInfo(_era_, consts.util);

        const result1 = await nftDistr.getUserEraAmount(consts.util, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.util, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(defaultComission);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(0);
        expect(result3[0][1]).to.be.eq(0);
        expect(result3[1]).to.be.eq(true);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);


        // ---------------------------
        // get back uniques
        // ---------------------------

        tx = await liquidStaking.stake([consts.uUtil1], [amount], { value: amount });
        await tx.wait();
        tx = await liquidStaking.stake([consts.uUtil3], [amount], { value: amount });
        await tx.wait();
        stakedAmount = stakedAmount.add(amount.mul(2));
    });

    it("remove all unique nft | remains (0 default)", async function () {
        await nextEra();

        const _era_ = await era();
        await nftInfo(_era_, consts.uUtil1);

        let tx = await liquidStaking.unstake([consts.uUtil1], [amount], false);
        await tx.wait();

        await nftInfo(_era_, consts.uUtil1);
        console.log('---------------------');
        await nftInfo(_era_, consts.uUtil3);

        tx = await liquidStaking.unstake([consts.uUtil3], [amount], false);
        await tx.wait();

        await nftInfo(_era_, consts.uUtil3);

        stakedAmount = stakedAmount.sub(amount.mul(2));

        const result1 = await nftDistr.getUserEraAmount(consts.uUtil3, signer.address, _era_);
        const result2 = await nftDistr.getUserInfo(signer.address);
        const result3 = await nftDistr.getEraAmount(_era_);
        const result4 = await nftDistr.getUtilAmount(consts.uUtil3, _era_);

        expect(result1[0]).to.be.eq(0);
        expect(result1[1]).to.be.eq(true);

        expect(result2[0]).to.be.eq(defaultComission);
        expect(result2[1]).to.be.eq(0);
        expect(result2[2]).to.be.eq(0);
        
        expect(result3[0][0]).to.be.eq(0);
        expect(result3[0][1]).to.be.eq(0);
        expect(result3[1]).to.be.eq(true);
        
        expect(result4[0]).to.be.eq(0);
        expect(result4[1]).to.be.eq(0);
        expect(result4[2]).to.be.eq(true);
    });
}); 