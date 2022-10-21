# About 1.5 

Version 1.5 implies the ability to stake to other dapps through a liquidstaking contract. For each dapp, a unique utility will be created in the distributor's contract, thanks to which it will be possible to control the shares of users in a particular dapp and track changes in their balances. <br>

The collection of rewards from all dapps will be done by the first user in the era. <br>
The calculation of rewards for each user will be carried out at the claim, taking into account the pre-calculated coefficients of rewards and balances per user at the time of each era. <br>

Rewards for all dapps are distributed evenly, according to the concept of DappsStaking. <br>

To store user balances in each dapp, mapping eraBalance is used, which records the user's balance in a specific era. Rewards are accrued only if the user has staked at least one whole era. For example, if a user stakes during era 3, then his balance will participate in era 4, and in era 5 he will be able to receive rewards for era 4 from this balance. <br>

In addition, the fee for a claim may differ for different users, depending on the availability of the relevant NFTs. To implement this logic, the nftDistributor contract was developed. <br>

# About DappsStaking

DappsStaking module is an ASTAR blockchain precompiler that allows users to stake into dapps they want to support. For this, users receive rewards and the dapps themselves also receive small rewards. <br>

All rewards are distributed among all dapps evenly and their number depends only on the staked balance. <br>

More details can be found with DappsStaking here: <br>
* Interface: https://portal.astar.network/#/astar/dapp-staking/discover <br>
* Docs: https://docs.astar.network/docs/dapp-staking/ <br>

All ASTAR precompiles you can seen here https://docs.astar.network/docs/EVM/precompiles <br>

# Smart-contracts

* __LiquidStaking.sol__
> _Contains 989 lines of code including comments and spaces_

Used to interact with the DappsStaking module to stake into different dapps that correspond to different utilities in the NDistributor contract. Previously, the smart contract was only used to stake into itself, but now it will be possible to stake into other dapps as well. Utilities for stake in yourself - "LiquidStaking". <br>
* __NDistributor.sol__
> _Contains 847 lines of code including comments and spaces_

Used to control the number of DNT tokens staked by the user in various dapps. Since after staking in different dapps, the user is always credited with a single nASTR token, it is necessary to know which dapp it belongs to. <br>
* __NFTDistributor.sol__
> _Contains 692 lines of code including comments and spaces_

A contract similar in concept to NDistributor, but tracks the balances of DNT tokens from users who own NFT as well as their commissions and fees. <br>
* __ArthswapAdapter.sol__
> _Contains 429 lines of code including comments and spaces_

* __ZenlinkAdapter.sol__
> _Contains 470 lines of code including comments and spaces_

The adapter contract is used to interact with Algem partners. Through it, the user can use his funds to earn additional income by selecting the application. After the user transfers funds and tokens to the adapter, they are sent to the partner's contract and start generating income, which is recorded on the balance of the adapter. The adapter monitors the user's balances and, upon request, withdraws the user's funds and their rewards. The adapter concept was introduced to improve the reliability of the Algem application and eliminate some vulnerabilities. <br>
* __AdaptersDistributor.sol__
> _Contains 96 lines of code including comments and spaces_

A simple contract to keep track of the user's balances in adapters in each era. After that, the total balance in all adapters is updated for the user in the LiquidStaking contract in the "AdaptersUtility" utility. <br>
* __NASTR.sol__
> _Contains 156 lines of code including comments and spaces_

ERC20 LP token that is credited after staking. <br>
* __Algem721.sol__
> _Contains 111 lines of code including comments and spaces_

ERC721 token giving a discount. <br>

# Tests

Fot tests connect http://80.78.24.17:9933 endpoint (id: 4369) or build astar-collator local chain. <br>

If you are connecting to our endpoint, your hardhhat config should contain:
```
...
networks: {
    hardhat: { },
    shidenLocal: {
        url: "http://80.78.24.17:9933",
        chainId: 4369,
        accounts: [`${process.env.PKEY}`, `${process.env.PKEY2}`],
    },
}
...
```

#### ASTAR chain nuances 

1) In order for the DappsStaking contract to return rewards, you need to call the function ```DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance)```. If this is not done, the rewards received from the claim will be staked immediately. This is done once and is implemented in the ```setting()``` function of the LiquidStaking contract. The function exists only for tests, since it has already been called and removed on the main contract. 
2) All interactions with DappsStaking can only be done if the ```DAPPS_STAKING.unbond_and_unstake()```, ```DAPPS_STAKING.withdraw_unbonded()```,```DAPPS_STAKING.claim_dapp()``` functions are called in the current era, otherwise it will be reverted.
3) Often the ASTAR network does not return a description of the error, returning just ```VM Exception while processing transaction: revert```. This is quite inconvenient and makes debugging very difficult. Basically, these are errors caused by the DappsStaking module. But it can also be caused by variable overflow/underflow or division by zero.
4) In addition, the ASTAR network sometimes just aborts a transaction and causes an error. In such cases, you need to try calling the transaction again or run the tests again.

#### Test nuances 

1) Since the tests are running on a real-time LAN, there is no way to use ```beforeEach()``` in tests and all tests are run sequentially. <br>
2) Regular EVM addresses and their private keys are suitable for running tests (as in MetaMask). <br>
3) It is not possible to run the main tests on a hardhat network or similar networks, since the ASTAR network uses the DappsStaking module precompiler, the code of which is implemented in Rust. <br>
4) In order to be able to stake in a dapp through the DappsStaking module, you first need to register it. Since the latest updates to Astar-collator, registering a dapp can only be done using sudo access, so registering a dapp via a function call will fail. You can register dapp by following the link http://80.78.24.17/#/sudo . To do this, select __dappsStaking__ and __register(developer, contractId)__ in the drop-down lists and choose any of the available accounts. Then select __Evm__ and enter the address of the dapp. Only one dapp can be registered per account! To register a dapp, you need to have money on the account balance. To top up account balance, go to ```Accounts->Transfer``` and transfer funds from any of the default accounts (Alice, Bob, Charlie, etc) which have a default balance. Remember that if several dapps are used in tests, then they all need to be registered in DappsStaking! If you run out of accounts, you can create them in the ```Accounts``` tab.
5) Before each launch of the test chain, you need to redeploy all contracts. To deploy contracts, enter your addresses in hardhat config and replenish their balances.

Run test example: <br>
```npx hardhat test test/audit/liquid_staking.ts --network shidenLocal``` <br>

```npx hardhat test test/audit/nft_distributor.ts --network shidenLocal``` <br>

```npx hardhat test test/audit/discount_from_nft.ts --network shidenLocal``` <br>

```npx hardhat test test/audit_adapter/ArthswapAdapter.js --network hardhat``` <br>

All test logs located in __.txt__ files in test folder.

# Deploy

Deploy scripts located in _scripts/audit/deploy.ts_ <br>Addresses of deployed contracts are stored in _config/audit/cfg.json_ <br> Used constants are stored in _config/audit/consts.json_ <br>

After deployment, it is necessary to register contracts in dappstaking. <br>
Before each launch of the deployment script, you must delete the file __unknowk-4369.json__ from .openzeppelin folder. <br>

deployment example: <br>```npx hardhat run scripts/audit/deploy.ts --network shidenLocal```

# Notes

1) The transition from handlers to adapters is planned to be smooth, so erashots functions will remains for another week after the deployment, after which they will be deleted and will no longer be used. <br>
2) Almost all smart contracts are implemented in a non-upgradeable format for ease of testing. In the future, when deploying to the mainnet, upgraded versions of all contracts will be implemented, old contracts will be upgraded, and new ones will be deployed. Changing contracts for an upgrade version will not change the logic of smart contracts.
3) Unused variables. In some smart contracts, unused variables are found that cannot be deleted due to the use of a proxy (you cannot violate the storage state). Often they are labeled ```/* unused and will removed with next proxy update */```. Or ```/* 1 -> 1.5 will removed with next proxy update */```, if the variable will only be used when switching from erashots.
4) At the moment, the LiquidStaking smart contract contains an error ```Contract code size exceeds 24576 bytes (a limit introduced in Spurious Dragon)``` because it includes too much functionality. Because of this, some functions in the smart contract are commented out (they will exist and be used when deploying to the mainnet) so that the contract can be deployed and tested. Basically, these are functions that do not affect the main logical part. At the moment, we will start developing the Diamond Contract (EIP-2535) to be able to split the logic into different contracts. This means that when switching to Diamond, the logic of the smart contract will not change and you can safely test it right now.
