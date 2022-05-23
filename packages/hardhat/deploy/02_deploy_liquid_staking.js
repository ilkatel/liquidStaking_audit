// deploy/01_deploy_nDistributor.js

const CONTRACT_NAME = "LiquidStaking";

const argsFile = "../contract-arguments/" + CONTRACT_NAME + "-args";
const { ethers } = require("hardhat");
const arguments = require(argsFile);

const localCHainId = "31337";

module.exports = async ({ getNamedAccounts, deployments, getChainId}) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    await deploy(CONTRACT_NAME, { 
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmations: 5,
    });

    const Contract = await ethers.getContract(CONTRACT_NAME, deployer);
};
module.exports.tags = [CONTRACT_NAME];
