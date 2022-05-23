// deploy/01_deploy_nDistributor.js

const CONTRACT_NAME = "NDistributor";

const { ethers } = require("hardhat");

const localCHainId = "31337";

module.exports = async ({ getNamedAccounts, deployments, getChainId}) => {
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    await deploy(CONTRACT_NAME, { 
        from: deployer,
        log: true,
        waitConfirmations: 5,
    });

    const Contract = await ethers.getContract(CONTRACT_NAME, deployer);
};
module.exports.tags = [CONTRACT_NAME];
