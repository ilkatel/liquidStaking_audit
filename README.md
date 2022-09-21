# About 1.5 

Version 1.5 implies the ability to stake to other dapps through a liquidstaking contract. For each dapp, a unique utility will be created in the distributor's contractor, thanks to which it will be possible to control the shares of users in a particular dapp and track changes in their balances.

The collection of rewards from all dapps will be done by the first user in the era.
The calculation of rewards for each user will be carried out at the claim, taking into account the pre-calculated coefficients of rewards and balances per user at the time of each era.

Rewards for all dapps are distributed evenly, according to the concept of dappstaking.

# Info 

Old version contracts -> contracts/old
Not upgredeable contracts -> contracts/common
Upgredeable versions -> contracts/upgredeable

__* Not upgredeable contracts built for local testing.__

# Dev 

Fot tests connect http://80.78.24.17:9933 endpoint (id: 4369) or build astar-collator local chain.

All test logs located in test/common/logs.txt.

test/upgredeable - tests for upgradeProxy and structures migration (NOT READY).