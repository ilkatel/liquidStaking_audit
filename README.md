![Algem Logo](https://github.com/DippyArtu/algem/blob/main/pics/logo-alpha.png?raw=true)

# Install
**Commands executed from the home directory**

Clone the source code, install dependencies.

```$git clone https://github.com/DippyArtu/algem.git```

```$cd ~/algem```

```$npm install```

See **Astar Cheatsheet.md** to setup local Astar instance
# Compile
**Commands executed from the home directory**

Check if everything compiles

```$cd ~/algem/packages/hardhat/```

```$npx hardhat compile```

# Deploy
**Commands executed from the ```algem/packages/hardhat``` directory**

Deploy contracts with this command, where ```CONTRACT_NAME``` derived from the desired contract and ```NETWORK_NAME``` can be found in ```hardhat.config.js```

```$yarn deploy --tags %CONTRACT_NAME% --network %NETWORK_NAME%```

For example, you want to deploy nSBY to Shibuya testnet:

```$yarn deploy --tags NSBY --network shibuyaTestnet```

* Deploy scritps can be found at ```algem/packages/hardhat/deploy```
* Contract arguments: ```algem/packages/hardhat/contract-arguments```

* Currently there are issues with passing arguments to upgradeable contracts via ```contract-arguments``` so ```nDistributor``` and ```LiquidStaking``` recieve them directly from the deploy script.

# Post-deploy routine
**NDistributor**
* ```addDnt("nSBY", address)``` pass NSBY addr
* ```addUtility("LiquidStaking")```
* ```addManager(address)``` pass Liquid Staking proxy addr
* ```addManager(address)``` pass NSBY addr
* ```setLiquidStaking(address)``` pass Liquid Staking proxy addr
**LiquidStaking**
* ```setup()```
* ```setDistr(address)``` pass NDistributor proxy addr
* ```setDntToken(address)``` pass NSBY addr
# Test
*Work in progress*


