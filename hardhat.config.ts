import * as dotenv from "dotenv";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

// import "./_tasks/toEvm";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999,
      },
    },
  },  
  networks: {
    hardhat: { },
    shidenLocal: {
      url: "http://80.78.24.17:9933",
      chainId: 4369,
      accounts: [`${process.env.PKEY}`, `${process.env.PKEY2}`],
    },
  },
  mocha: {
    timeout: 1600000,  
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
  },
  defaultNetwork: "shidenLocal",
};

export default config;
