////////////////////////
// NOT FINISHED TESTS //
////////////////////////

import {default as cfg} from "../../config/upgredeable/cfg.json";
import {default as consts} from "../../config/upgredeable/consts.json";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers, upgrades } from "hardhat";
import { LiquidStakingOld, NDistributorOld } from "../../typechain-types/contracts/old";
import { NASTROld } from "../../typechain-types/contracts/old/nASTROld.sol";
import { DappsStaking } from "../../typechain-types/contracts/upgredeable/interfaces";

let signer: SignerWithAddress;  // 0xDE47D123fE04f164AFc64034B9D5F8790Ace7a9a
let acc: SignerWithAddress;  // 0x545598Fe8f589Cb31d6c6C6FbeDE58C54DeE6638
let accs: SignerWithAddress[];

let liquidStaking: LiquidStakingOld;
let nASTR: NASTROld;
let distr: NDistributorOld;
let dappsStaking: DappsStaking;

const zeroHash = ethers.constants.HashZero;
const zeroAddress = ethers.constants.AddressZero;

let amount: BigNumber = ethers.utils.parseEther("1000");
let ofset: BigNumber = BigNumber.from("1000000000");

let rewPerEra: BigNumber;
let unbPeriod: BigNumber;

let lastEra: BigNumber;

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

async function update() {
    const _era = await era();

    try {
        let tx = await liquidStaking.sync(_era.sub(1));
        await tx.wait();
    } catch(_) {}
    
    while (true) {
        try {
            let tx = await liquidStaking.claimRewards();
            await tx.wait();
        } catch(e) { 
            console.log('error', e); 
            return; 
        }
    }
}

describe("Presets", function () {
    before(async function () {
        accs = await ethers.getSigners();   
        signer = accs[0];
        acc = accs[1];

        console.log('signer:  ', signer.address);
        console.log('balance: ', await signer.getBalance());
        console.log('--------------------');
        console.log('acc:  ', acc.address);
        console.log('balance: ', await acc.getBalance());

        liquidStaking = await ethers.getContractAt('LiquidStakingOld', cfg.liquidStaking, signer);
        dappsStaking = await ethers.getContractAt('contracts/old/interfaces/DappsStaking.sol:DappsStaking', cfg.dappsStaking, signer);
        // nASTR = await ethers.getContractAt('NASTROld', cfg.nASTR, signer);
        distr = await ethers.getContractAt('NDistributorOld', cfg.distr, signer);
        
        
        await nextEra();    
    });

    it("print DS info", async function () {
        unbPeriod = await dappsStaking.read_unbonding_period();
        console.log('unb period:  ', unbPeriod);
        console.log('current era: ', await dappsStaking.read_current_era());
    });

    it("buffer test", async function () {
        let _era = await era(); 
        console.log('last claimed: ', await liquidStaking.lastClaimed(), 'current era: ', await dappsStaking.read_current_era());
        lastEra = _era;

        expect(await liquidStaking.buffer(signer.address, _era)).to.be.eq(0);

        let tx = await liquidStaking.stake({value: amount});
        await tx.wait();

        try {
            let tx = await liquidStaking.setting();
            await tx.wait();
        } catch(_) {}
        console.log('last claimed: ', await liquidStaking.lastClaimed(), 'current era: ', await dappsStaking.read_current_era());
        // await update();
        // await update();
        tx = await liquidStaking.eraShot(signer.address, consts.util, consts.dnt);
        await tx.wait();
        console.log('last claimed: ', await liquidStaking.lastClaimed(), 'current era: ', await dappsStaking.read_current_era());
        expect(await liquidStaking.buffer(signer.address, _era)).to.be.eq(amount);

        await nextEra();
        _era = await era();

        expect(await liquidStaking.buffer(signer.address, _era)).to.be.eq(0);
        tx = await liquidStaking.stake({value: amount});
        await tx.wait();
        console.log('last claimed: ', await liquidStaking.lastClaimed(), 'current era: ', await dappsStaking.read_current_era());
        // await update();
        // await update();     
        tx = await liquidStaking.eraShot(signer.address, consts.util, consts.dnt);
        await tx.wait();
        console.log('last claimed: ', await liquidStaking.lastClaimed(), 'current era: ', await dappsStaking.read_current_era());

        expect(await liquidStaking.buffer(signer.address, _era)).to.be.eq(amount);
        expect(await distr.getUserDntBalanceInUtil(signer.address, consts.dnt, consts.util)).to.be.eq(amount.mul(2));
    });

    it("storage migration test", async function () {
        console.log(await ethers.provider.getBalance(liquidStaking.address));
        console.log('last claimed: ', await liquidStaking.lastClaimed(), 'current era: ', await dappsStaking.read_current_era());

        await nextEra();
        let _era = await era();

        // await update();
        // await update();
        let tx = await liquidStaking.eraShot(signer.address, consts.util, consts.dnt);
        await tx.wait();

        const liquidStakingFactory = await ethers.getContractFactory("contracts/upgredeable/LiquidStaking.sol:LiquidStaking");
        const liquidStaking1_5 = await upgrades.upgradeProxy(liquidStaking.address, liquidStakingFactory);
        await liquidStaking1_5.deployed();
        await liquidStaking1_5.deployTransaction.wait();

        tx = await liquidStaking1_5.migrateStorage(signer.address);
        await tx.wait();
        
        console.log(await liquidStaking1_5.lastEraTotalBalance());
        console.log((await liquidStaking1_5.dapps(consts.util)).stakedBalance);
        console.log(await liquidStaking1_5.getUserEraBalance(signer.address, consts.util, _era.sub(1)));
        console.log(await liquidStaking1_5.getUserEraBalance(signer.address, consts.util, _era));
        console.log(await liquidStaking1_5.getUserEraBalance(signer.address, consts.util, _era.add(1)));
    });
});