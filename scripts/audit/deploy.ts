import { ethers, upgrades } from "hardhat";
const fs = require('fs');

import {default as cfg} from "../../config/audit/cfg.json";
import {default as consts} from "../../config/audit/consts.json";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { LiquidStaking__factory, NASTR__factory, NDistributor__factory, NFTDistributor__factory, AdaptersDistributor__factory } from "../../typechain-types/factories/contracts/audit";

import { MockDapp__factory } from "../../typechain-types/factories/contracts/audit/mock/MockDapp__factory";

let signer: SignerWithAddress;
let tx: any;

async function deployDistr() {
    const distr = await new NDistributor__factory(signer).deploy();
    await distr.deployed();

    cfg.distr = distr.address;

    console.log('disributor: ', cfg.distr);

    tx = await distr.initialize2();
    await tx.wait();
}   

async function deployNASTR() {
    const nASTR = await new NASTR__factory(signer).deploy(cfg.distr);
    await nASTR.deployed();

    cfg.nASTR = nASTR.address;

    console.log('nASTR: ', cfg.nASTR);

    const distr = await ethers.getContractAt('contracts/audit/NDistributor.sol:NDistributor', cfg.distr, signer);
    tx = await distr.addDnt(consts.dnt, cfg.nASTR);
    await tx.wait();
    
    tx = await distr.addManager(cfg.nASTR);
    await tx.wait();

    tx = await distr.addUtility(consts.util);
    await tx.wait();

    console.log('dnt: ', consts.dnt, '| util: ', consts.util);
} 

async function deployLiquidStaking() {
    const liquidStaking = await new LiquidStaking__factory(signer).deploy(consts.dnt, consts.util, cfg.distr);
    await liquidStaking.deployed()

    cfg.liquidStaking = liquidStaking.address;

    console.log('liquidStaking: ', cfg.liquidStaking);
    console.log('REGISTER LIQUIDSTAKING PLEASE!');

    const distr = await ethers.getContractAt('contracts/audit/NDistributor.sol:NDistributor', cfg.distr, signer);
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

    const mockDapp2 = await new MockDapp__factory(signer).deploy();
    await mockDapp2.deployed();

    cfg.mockDapp2 = mockDapp2.address;

    console.log('mockDapp2: ', cfg.mockDapp2);
    console.log('REGISTER MOCKDAPP2 PLEASE!');

    const mockDapp3 = await new MockDapp__factory(signer).deploy();
    await mockDapp3.deployed();

    cfg.mockDapp3 = mockDapp3.address;

    console.log('mockDapp3: ', cfg.mockDapp3);
    console.log('REGISTER MOCKDAPP3 PLEASE!');
}

async function addDaps() {
    const liquidStaking = await ethers.getContractAt("contracts/audit/LiquidStaking.sol:LiquidStaking", cfg.liquidStaking, signer);

    tx = await liquidStaking.addDapp(consts.util2, cfg.mockDapp);
    await tx.wait();

    console.log('util2: ', consts.util2, '| dapp: ', cfg.mockDapp);

    tx = await liquidStaking.addDapp(consts.uUtil1, cfg.mockDapp2);
    await tx.wait();

    console.log('uUtil1: ', consts.uUtil1, '| dapp: ', cfg.mockDapp2);

    tx = await liquidStaking.addDapp(consts.uUtil3, cfg.mockDapp3);
    await tx.wait();

    console.log('uUtil3: ', consts.uUtil3, '| dapp: ', cfg.mockDapp3);
}

async function deployAdaptersDistributor() {
    const adaptersDistr = await new AdaptersDistributor__factory(signer).deploy(cfg.liquidStaking);
    await adaptersDistr.deployed();

    cfg.adapterDistr = adaptersDistr.address;

    console.log('adaptersDistributor: ', cfg.adapterDistr);
}

async function deployNftDistributor() {
    const nftDistr = await new NFTDistributor__factory(signer).deploy(cfg.distr, cfg.nASTR, cfg.liquidStaking, cfg.adapterDistr);
    await nftDistr.deployed();

    cfg.nftDistr = nftDistr.address;

    console.log('NftDistributor: ', cfg.nftDistr);

    const adaptersDitributor = await ethers.getContractAt("contracts/audit/AdaptersDistributor.sol:AdaptersDistributor", cfg.adapterDistr);
    tx = await adaptersDitributor.setNftDistributor(cfg.nftDistr);
    await tx.wait();

    const liquidStaking = await ethers.getContractAt("contracts/audit/LiquidStaking.sol:LiquidStaking", cfg.liquidStaking, signer);

    tx = await liquidStaking.initialize2(cfg.nftDistr, cfg.adapterDistr);
    await tx.wait();

    const nASTR = await ethers.getContractAt("contracts/audit/NASTR.sol:NASTR", cfg.nASTR, signer);
    tx = await nASTR.setNftDistributor(cfg.nftDistr);
    await tx.wait();
}

async function deployNft() {
    const nftFactory = await ethers.getContractFactory("contracts/audit/Algem721.sol:Algem721");

    let _nft = await upgrades.deployProxy(nftFactory, ['aaa', 'aaa', 'aaa']);
    await _nft.deployed();
    await _nft.deployTransaction.wait();

    tx = await _nft.initialize2(cfg.nftDistr, consts.util, 50);
    await tx.wait();

    cfg.nft = _nft.address;

    console.log('nft deployed', cfg.nft);

    const nftDistr = await ethers.getContractAt("contracts/audit/NFTDistributor.sol:NFTDistributor", cfg.nftDistr);

    tx = await nftDistr.addUtility(_nft.address, 7, false);
    await tx.wait();


    _nft = await upgrades.deployProxy(nftFactory, ['bbb', 'bbb', 'bbb']);
    await _nft.deployed();
    await _nft.deployTransaction.wait();

    tx = await _nft.initialize2(cfg.nftDistr, consts.util2, 50);
    await tx.wait();

    cfg.nft2 = _nft.address;

    console.log('nft2 deployed', _nft.address);

    tx = await nftDistr.addUtility(_nft.address, 5, false);
    await tx.wait();

    _nft = await upgrades.deployProxy(nftFactory, ['ccc', 'ccc', 'ccc']);
    await _nft.deployed();
    await _nft.deployTransaction.wait();

    tx = await _nft.initialize2(cfg.nftDistr, consts.uUtil1, 50);
    await tx.wait();

    cfg.unft = _nft.address;

    console.log('unft1 deployed', _nft.address);

    tx = await nftDistr.addUtility(_nft.address, 8, true);
    await tx.wait();

    _nft = await upgrades.deployProxy(nftFactory, ['ddd', 'ddd', 'ddd']);
    await _nft.deployed();
    await _nft.deployTransaction.wait();

    tx = await _nft.initialize2(cfg.nftDistr, consts.uUtil3, 50);
    await tx.wait();

    cfg.unft2 = _nft.address;

    console.log('unft3 deployed', _nft.address);

    tx = await nftDistr.addUtility(_nft.address, 3, true);
    await tx.wait();
}

async function deploy() {
    console.log('Deploy start');

    let acc2: SignerWithAddress;

    [ signer, acc2 ] = await ethers.getSigners();
    console.log('signer: ', signer.address);
    console.log('acc: ', acc2.address);

    cfg.dappsStaking = "0x0000000000000000000000000000000000005001";

    await deployDistr();
    await deployNASTR();
    await deployLiquidStaking();
    await deployMockDapp();
    await addDaps();
    await deployAdaptersDistributor();
    await deployNftDistributor();
    await deployNft();

    await fs.writeFileSync("config/audit/cfg.json", JSON.stringify(cfg), function(err: any) {
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
