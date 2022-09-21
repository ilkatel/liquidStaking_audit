import { ethers, upgrades } from "hardhat";
const fs = require('fs');

import {default as cfg} from "../../config/upgredeable/cfg.json";
import {default as consts} from "../../config/upgredeable/consts.json";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

let signer: SignerWithAddress;

async function deployDistr() {
    const distrFactory = await ethers.getContractFactory("NDistributorOld");
    const distr = await upgrades.deployProxy(distrFactory);
    await distr.deployed();
    await distr.deployTransaction.wait();

    cfg.distr = distr.address;

    console.log('disributor: ', cfg.distr);
}   

async function deployNASTR() {
    const nASTRFactory = await ethers.getContractFactory("NASTROld");
    const nASTR = await upgrades.deployProxy(nASTRFactory, [cfg.distr]);
    await nASTR.deployed();
    await nASTR.deployTransaction.wait();

    cfg.nASTR = nASTR.address;

    console.log('nASTR: ', cfg.nASTR);

    const distr = await ethers.getContractAt('NDistributorOld', cfg.distr, signer);
    const tx1 = await distr.addDnt(consts.dnt, cfg.nASTR);
    await tx1.wait();

    const tx2 = await distr.addUtility(consts.util);
    await tx2.wait();

    const tx3 = await distr.addManager(cfg.nASTR);
    await tx3.wait();

    console.log('dnt: ', consts.dnt, '| util: ', consts.util);
} 

async function deployLiquidStaking() {
    const liquidStakingFactory = await ethers.getContractFactory("LiquidStakingOld");
    const liquidStaking = await upgrades.deployProxy(liquidStakingFactory, [consts.dnt, consts.util, cfg.distr, cfg.nASTR]);
    await liquidStaking.deployed();
    await liquidStaking.deployTransaction.wait();

    cfg.liquidStaking = liquidStaking.address;

    console.log('liquidStaking: ', cfg.liquidStaking);
    console.log('REGISTER LIQUIDSTAKING PLEASE!');

    const distr = await ethers.getContractAt('NDistributorOld', cfg.distr, signer);
    const tx = await distr.setLiquidStaking(cfg.liquidStaking);
    await tx.wait();
    const tx1 = await distr.addManager(cfg.liquidStaking);
    await tx1.wait();

    console.log('liquidStaking setted');
}

async function deploy() {
    console.log('Deploy start');

    [ signer ] = await ethers.getSigners();
    console.log('signer: ', signer.address);

    cfg.dappsStaking = "0x0000000000000000000000000000000000005001";

    await deployDistr();
    await deployNASTR();
    await deployLiquidStaking();

    await fs.writeFileSync("config/upgredeable/cfg.json", JSON.stringify(cfg), function(err: any) {
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
