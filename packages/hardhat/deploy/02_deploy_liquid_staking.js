// deploy/01_deploy_nDistributor.js

const CONTRACT_NAME = "LiquidStaking";

const { ethers } = require("hardhat");

const localCHainId = "31337";

module.exports = async ({ getNamedAccounts, deployments, getChainId}) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    const contract = await ethers.getContractFactory(CONTRACT_NAME);
    //const instance = await upgrades.deployProxy(contract, ["0xAB299124383f8419ebC8B4f3cb70d15e6602252D"], { deployer });
    const instance = await upgrades.upgradeProxy("0x3C5D888400E60EE94895de705744bB92367554f9", contract)
    await instance.deployed();
    console.log(CONTRACT_NAME + " deployed to: " + instance.address);
};
module.exports.tags = [CONTRACT_NAME];
