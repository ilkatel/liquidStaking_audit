// deploy/00_deploy_your_contract.js

// to verify
// yarn verify --constructor-args ALGMarguments.js CONTRACT_ADDRESS --network binanceTestnet


const { ethers } = require("hardhat");

const localChainId = "31337";

const contractName = "ALGM";

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy(contractName, {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [
      "0x21D88df5b09C6e1B7FAf2806261F032A19A290E8", // Incentive treasury
      "0x54377DeAb559FFD702304e625814e54b213815F1", // Team treasury
      "0xa69b0364e0f791f2ecBA92CC1be77B225683d962", // Community treasury
      "0xF77636DbECa81f5D8d5937d17bbA046059cF0c36" // Reserve treasury
    ],

    // DEV HARDHAT
    // owner 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    // args: [
    //   "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", // Incentive treasury
    //   "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", // Team treasury
    //   "0x90F79bf6EB2c4f870365E785982E1f101E93b906", // Community treasury
    //   "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65" // Reserve treasury
    // ],

    log: true,
    waitConfirmations: 5,
  });

  // Getting a previously deployed contract
  const ALGM = await ethers.getContract(contractName, deployer);
};
module.exports.tags = [contractName];
