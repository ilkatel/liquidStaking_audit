# About 1.5 

Version 1.5 implies the ability to stake to other dapps through a liquidstaking contract. For each dapp, a unique utility will be created in the distributor's contractor, thanks to which it will be possible to control the shares of users in a particular dapp and track changes in their balances.

The collection of rewards from all dapps will be done by the first user in the era.
The calculation of rewards for each user will be carried out at the claim, taking into account the pre-calculated coefficients of rewards and balances per user at the time of each era.

Rewards for all dapps are distributed evenly, according to the concept of dappstaking.

To store user balances in each dapp, mapping eraBalance is used, which records the user's balance in a specific era. Rewards are accrued only if the user has staked at least one whole era. For example, if a user stakes during era 3, then his balance will participate in era 4, and in era 5 he will be able to receive rewards for era 4 from this balance.

# Info 

Old version contracts -> contracts/old <br>
Not upgredeable contracts -> contracts/common <br>
Upgredeable versions -> contracts/upgredeable <br>

__* Not upgredeable contracts built for local testing.__

# Dev 

Fot tests connect http://80.78.24.17:9933 endpoint (id: 4369) or build astar-collator local chain.

# Deploy

Deploy scripts located in scripts/../deploy.ts <br>
Addresses of deployed contracts are stored in config/../cfg.json <br>
After deployment, it is necessary to register contracts in dappstaking <br>

deployment example: <br>
```npx hardhat run scripts/common/deploy.ts --network shidenLocal```

# Tests

All test logs located in test/common/logs.txt.

test/upgredeable - tests for upgradeProxy and structures migration (__NOT READY__).

run test example: <br>
```npx hardhat test test/common/index.ts --network shidenLocal```

# Note

The transition from handlers to adapters is planned to be smooth, so erashots will remain for another week after the deployment, after which they will be deleted and will no longer be used.