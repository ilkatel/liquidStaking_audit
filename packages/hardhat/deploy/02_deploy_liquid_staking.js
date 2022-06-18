// deploy/01_deploy_nDistributor.js

const CONTRACT_NAME = "LiquidStaking";

const { ethers, upgrades } = require("hardhat");

const localCHainId = "31337";

module.exports = async ({ getNamedAccounts, deployments, getChainId}) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    const contract = await ethers.getContractFactory(CONTRACT_NAME);
    const instance = await upgrades.deployProxy(contract, { deployer });
    //const instance = await upgrades.upgradeProxy("0xD9E81aDADAd5f0a0B59b1a70e0b0118B85E2E2d3", contract)
    await instance.deployed();
    console.log(CONTRACT_NAME + " deployed to: " + instance.address);
};
module.exports.tags = [CONTRACT_NAME];
