# Astar ✨

- [[#Prep]]
- [[#Setting up Local envo mac]]
- [[#Metamask setup]]
- [[#Local Contract deployment]]
- [[#Astar over hardhat]]
- [[#Astar Base — on-chain EVM Database]]
- [[#EVM Precompiles]]
- [[#Links]]
- 
- [Astar Portal](https://portal.astar.network/#/assets)


## Prep

- Get polkadot extension, set up wallets and connect to Astar portal
	- [Guide](https://docs.astar.network/tutorial/how-to/how-to-make-a-kusama-polkadot-address)





## Setting up Local envo (mac)

[Ethereum Contract in Your Local Environment](https://docs.astar.network/build/smart-contracts/ethereum-virtual-machine/evm-smart-contracts)

Following will install Plasm node, [Substrate node](https://github.com/paritytech/substrate/tree/master/docs#shared-steps) and [Astar Network](https://github.com/AstarNetwork/Astar/tree/development/dusty)

*All from home directory*

1. `curl https://sh.rustup.rs -sSf | sh`
2. `rustup update nightly`
3. `rustup target add wasm32-unknown-unknown --toolchain nightly`
4. `rustup update stable`
5. `brew install cmake pkg-config openssl git llvm`
6. `git clone --recurse-submodules https://github.com/PlasmNetwork/Astar.git`
7. `cd Astar`
8. `cargo build --release`
9. Run a temporary developer node locally to test if it works
	- . `./target/release/astar-collator --dev --tmp`
10. Add alias to your profile (ie `.zsh_aliases`)
	- `alias astar="~/Astar/target/release/astar-collator"`
11. `source ~/.zsh_aliaces` or open new terminal
12. Start Astar dev node
	- `astar --dev -l evm=debug`





## Metamask setup

#### Mapping Astar Native to EVM address 

-[How to](https://docs.astar.network/tutorial/how-to/how-to-make-a-kusama-polkadot-address)

---

**Local network**
```
Network Name: Shiden Local
New RPC URL: http://localhost:9933
Chain ID: 4369
Symbol: ASTL
```

[Block Explorer](https://polkadot.js.org/apps/?rpc=ws%3A%2F%2F127.0.0.1%3A9944#/explorer)

---

**Shibuya network (parachain testnet)**
```
Network Name: Shibuya
New RPC URL: https://rpc.shibuya.astar.network:8545/
Chain ID: 81
Symbol: SBY
Block Explorer URL: https://blockscout.com/shibuya
```

Can get SBY from faucet at [Astar Portal](https://portal.astar.network/#/assets), works with metamask

---

**Astar network (mainnet)**
```
Network Name: Astar Network Mainnet
New RPC URL: https://evm.astar.network
Chain ID: 592
Symbol: ASTR
Block Explorer URL: https://blockscout.com/astar
```


## Local Contract deployment

- Launch a node in the development environment

```shell
astar --port 30333 --ws-port 9944 --rpc-port 9933 --rpc-cors all --alice --dev
```

	-	Use port 30333 for P2P TCP connection
	-   Use port 9944 for WebSocket connection
	-   Use port 9933 for RPC
	-   Accept any origins for HTTP and WebSocket connections
	-   Enable Alice session keys
	-   Launch network in development mode

- **Ok this is a pain but bare with me** Get funds and top up metamask and hardhat deployer acc
	- Go to [Astar Portal](https://portal.astar.network/#/assets), connect your Polkadot wallet, switch network to Local Network (top right corner) and copy address
	-  Go to [Explorer](https://polkadot.js.org/apps/?rpc=ws%3A%2F%2F127.0.0.1%3A9944#/explorer) ---> Accounts ---> choose Alice (with 1 BASTL), click Send
	- Paste polkadot address into "send to", choose amount (ie 10000), click Send
	- Come back to [Astar Portal](https://portal.astar.network/#/assets), you should see the deposit
	- Under Assets, click on Transfer next to Transferable balance ---> enter your Metamask (evm) address, amount and send
	- Make sure Metamask is connected to Shiden (local network), you should see your ASTL — can now deploy contracts on local chain from remix or hardhat
- Deploy contract

```shell
yarn deploy --network shidenLocal
```

- Go to [Explorer](https://polkadot.js.org/apps/?rpc=ws%3A%2F%2F127.0.0.1%3A9944#/explorer)  ---> Developer ---> Contracts to interact with contracts

==How to find EVM contracts? Probably AstarPass comes in here==

[Source](https://docs.astar.network/tutorial/develop-and-deploy-your-first-smart-contract-on-aster-shiden-evm/deploy-contract-on-local-network)

## Astar over hardhat

- Go to [Astar Portal](https://portal.astar.network/#/assets), connect to Shibuya network and get funds from faucet ---> top up your deployer account
- Deploy contract

```shell
yarn deploy --network shibuyaTestnet <------ Testnet
yarn deploy --network astar			 <------ Mainnet
```

- Find the contract at [Explorer]
- TBC how to verify


## Astar Base — on-chain EVM Database

- [AstarBase](https://docs.astar.network/build/smart-contracts/ethereum-virtual-machine/astarbase)




## EVM Precompiles

- [EVM Precompiles](https://docs.astar.network/build/smart-contracts/ethereum-virtual-machine/evm-precompiles)




---

### Links

- [Astar Subscan](https://astar.subscan.io/)
- [Using Hardhat](https://docs.astar.network/build/smart-contracts/ethereum-virtual-machine/using-hardhat)
- [Set up on-chain identity](https://docs.astar.network/tutorial/how-to/on-chain-identity)