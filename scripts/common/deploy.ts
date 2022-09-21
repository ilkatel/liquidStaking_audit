import { ethers } from "hardhat";
const fs = require('fs');

import {default as cfg} from "../../config/common/cfg.json";
import {default as consts} from "../../config/common/consts.json";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { LiquidStaking1_5__factory, NDistributor1_5__factory, NASTR1_5__factory } from "../../typechain-types";
import { MockDapp__factory } from "../../typechain-types/factories/contracts/common/mock";


let signer: SignerWithAddress;


async function deployDistr() {
    const distr = await new NDistributor1_5__factory(signer).deploy();
    await distr.deployed();

    cfg.distr = distr.address;

    console.log('disributor: ', cfg.distr);
}   

async function deployNASTR() {
    const nASTR = await new NASTR1_5__factory(signer).deploy(cfg.distr);
    await nASTR.deployed();

    cfg.nASTR = nASTR.address;

    console.log('nASTR: ', cfg.nASTR);

    const distr = await ethers.getContractAt('NDistributor1_5', cfg.distr, signer);
    const tx1 = await distr.addDnt(consts.dnt, cfg.nASTR);
    await tx1.wait();

    const tx2 = await distr.addUtility(consts.util);
    await tx2.wait();

    const tx3 = await distr.addManager(cfg.nASTR);
    await tx3.wait();

    console.log('dnt: ', consts.dnt, '| util: ', consts.util);
} 

async function deployLiquidStaking() {
    const liquidStaking = await new LiquidStaking1_5__factory(signer).deploy(consts.dnt, consts.util, cfg.distr, cfg.nASTR, cfg.dappsStaking);
    await liquidStaking.deployed()

    cfg.liquidStaking = liquidStaking.address;

    console.log('liquidStaking: ', cfg.liquidStaking);
    console.log('REGISTER LIQUIDSTAKING PLEASE!');

    const distr = await ethers.getContractAt('NDistributor1_5', cfg.distr, signer);
    const tx = await distr.setLiquidStaking(cfg.liquidStaking);
    await tx.wait();

    console.log('liquidStaking setted');
}

async function deployMockDapp() {
    const mockDapp = await new MockDapp__factory(signer).deploy();
    await mockDapp.deployed();

    cfg.mockDapp = mockDapp.address;

    console.log('mockDapp: ', cfg.mockDapp);
    console.log('REGISTER MOCKDAPP PLEASE!');
}

async function addDaps() {
    const liquidStaking = await ethers.getContractAt("LiquidStaking1_5", cfg.liquidStaking, signer);

    const tx1 = await liquidStaking.addDapp(consts.util2, cfg.mockDapp);
    await tx1.wait();

    console.log('util2: ', consts.util2, '| dapp: ', cfg.mockDapp);
}

async function deploy() {
    console.log('Deploy start');

    [ signer ] = await ethers.getSigners();
    console.log('signer: ', signer.address);

    cfg.dappsStaking = "0x0000000000000000000000000000000000005001";

    await deployDistr();
    await deployNASTR();
    await deployLiquidStaking();
    await deployMockDapp();
    await addDaps();

    await fs.writeFileSync("config/common/cfg.json", JSON.stringify(cfg), function(err: any) {
        if (err) {
            console.log(err);
        }
    });

    console.log('Deploy finished');
}

deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
