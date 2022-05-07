// deploy/00_deploy_your_contract.js

// to verify
// yarn verify --constructor-args ALGMarguments.js CONTRACT_ADDRESS --network binanceTestnet

// <----------------------------------------------- specify contract name
const CONTRACT_NAME = "ALGM";
//const CONTRACT_NAME = "nASTR";

//const argsFile = "../contract-arguments/" + CONTRACT_NAME + "-args";
const { ethers } = require("hardhat");
const arguments = require("../contract-arguments/ALGM-args");

const localChainId = "31337";

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy(CONTRACT_NAME, {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: arguments,
    log: true,
    waitConfirmations: 5,
  });

  // Getting a previously deployed contract
  const ALGM = await ethers.getContract(CONTRACT_NAME, deployer);
};
module.exports.tags = [CONTRACT_NAME];
