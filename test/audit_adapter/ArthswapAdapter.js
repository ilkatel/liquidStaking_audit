const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { connect } = require("http2");

/*
 * @title:   ArthswapAdapter test script
 * @author:  Aleksey Zhelyabin
*/

if (true) {
  describe("ArthswapAdapter", function () {
    // users vars
    let owner, user1, user2

    // contracts vars
    let nastr, lp, arsw, pool, farm, pair, adapter

    // instances
    let nastrInst, lpInst, arswInst, poolInst, farmInst, pairInst, adapterInst

    // connected users
    let user1Adapter, user1Ntoken, user1ARSWToken, user1Farm, user1Pair, user2Adapter, user2Ntoken, user2ARSWToken, user2Farm, user2Pair

    // other vars
    let eth, oneHour

    before(async function () {
      // assign users
      [owner, user1, user2] = await ethers.getSigners();

      // set vars
      eth = ethers.utils.parseEther("1")
      kiloEth = ethers.utils.parseEther("1000")
      oneHour = 60 * 60

      // tokens factories
      const NastrFactory = await ethers.getContractFactory("MockERC20");
      const LpFactory = await ethers.getContractFactory("MockERC20");
      const ArswFactory = await ethers.getContractFactory("MockERC20");

      // Arthswap contracts
      const PoolFactory = await ethers.getContractFactory("MockArthswapRouter");
      const FarmFactory = await ethers.getContractFactory("MockArthswapMasterChef");
      const PairFactory = await ethers.getContractFactory("MockArthswapPair");
      const AdapterFactory = await ethers.getContractFactory("ArthswapAdapter")

      // deploy contracts
      nastr = await NastrFactory.deploy("nASTR", "nASTR token")
      lp = await LpFactory.deploy("LP", "LP token")
      arsw = await ArswFactory.deploy("ARSW", "ARSW token")
      pool = await PoolFactory.deploy(lp.address, nastr.address)
      farm = await FarmFactory.deploy(arsw.address, lp.address)
      pair = await PairFactory.deploy(pool.address, lp.address)
      adapter = await upgrades.deployProxy(AdapterFactory, [
        farm.address,
        pool.address,
        nastr.address,
        lp.address,
        pair.address,
        arsw.address,
        "26"
      ])

      // set instances
      nastrInst = new ethers.Contract(nastr.address, abiERC20, ethers.provider)
      lpInst = new ethers.Contract(lp.address, abiERC20, ethers.provider)
      arswInst = new ethers.Contract(arsw.address, abiERC20, ethers.provider)
      poolInst = new ethers.Contract(pool.address, abiPool, ethers.provider)
      farmInst = new ethers.Contract(farm.address, abiFarm, ethers.provider)
      pairInst = new ethers.Contract(pair.address, abiPair, ethers.provider)
      adapterInst = new ethers.Contract(adapter.address, abiAdapter, ethers.provider)

      // connected users
      ownerAdapter = adapterInst.connect(owner)

      user1Adapter = adapterInst.connect(user1)
      user1Ntoken = nastrInst.connect(user1)
      user1ARSWToken = arswInst.connect(user1)
      user1Farm = farmInst.connect(user1)
      user1Pair = pairInst.connect(user1)
      user1Lp = lpInst.connect(user1)

      user2Adapter = adapterInst.connect(user2)
      user2Ntoken = nastrInst.connect(user2)
      user2ARSWToken = arswInst.connect(user2)
      user2Farm = farmInst.connect(user2)
      user2Pair = pairInst.connect(user2)

      // mint tokens to users
      const deployerNastr = new ethers.Contract(nastr.address, abiERC20, owner)
      await deployerNastr.mint(user1.address, ethers.utils.parseEther("100"))
      await deployerNastr.mint(user2.address, ethers.utils.parseEther("100"))

      // set initial LP supply
      const ownerLp = lpInst.connect(owner)
      await ownerLp.mint(owner.address, ethers.utils.parseEther("100"))
    });

    describe("Check if only pool can send ether to adapter", function() {
      it("Error when send ether not via pool", async function() {
        await expect(user1.sendTransaction({to: adapter.address, from: user1.address, value: eth}))
        .to.be.revertedWith("Sending tokens not allowed")
      })
    })

    describe("Check condition when withdraw revenue", function() {
      it("Error when not enough ARSW", async function() {
        await expect(ownerAdapter.withdrawRevenue(ethers.utils.parseEther("100")))
        .to.be.revertedWith("Not enough ARSW revenue")
      })

      it("Error when zero value", async function() {
        await expect(ownerAdapter.withdrawRevenue("0"))
        .to.be.revertedWith("Should be greater than zero")
      })
    })

    if (true) {
      describe("Check conditions when withdrawLP", function() {
        it("Error when not enough deposited LLP tokens", async function() {
          await expect(user1Adapter.withdrawLP(ethers.utils.parseEther("100"), false)).to.be.revertedWith("Not enough deposited LP tokens")
        })
  
        it("Error when zero value", async function() {
          await expect(user1Adapter.withdrawLP("0", false)).to.be.revertedWith("Should be greater than zero")
        })
      })
  
      describe("Check condition when user claim rewards", function() {
        it("Error when claim without rewards", async function() {
          await expect(user1Adapter.claim()).to.be.revertedWith("User has no any rewards")
        })
      })

      describe("Check conditions when deosit LP", function() {
        it("Error when not enough LP tokens", async function() {
          await expect(user1Adapter.depositLP(ethers.utils.parseEther("100"))).to.be.revertedWith("Not enough LP tokens")
        })
  
        it("Error when zero value", async function() {
          await expect(user1Adapter.depositLP("0")).to.be.revertedWith("Should be greater than zero")
        })
      })

      describe("Check conditions when adding LP tokens", function() {
        it("Error when zero value", async function() {
          await expect(user1Adapter.addLp("0", false)).to.be.revertedWith("Should be greater than zero")
        })
  
        it("Error when not enough LP on balance", async function() {
          await expect(user1Adapter.addLp(eth, false)).to.be.revertedWith("Not enough LP tokens on balance")
        })
      })

      describe("Check conditions when removing liquidity", function() {
        it("Error when zero value", async function() {
          await expect(user1Adapter.removeLiquidity("0")).to.be.revertedWith("Should be greater than zero")
        })
  
        it("Error when removing liquidity and user hasn't any LP tokens", async function() {
          await expect(user1Adapter.removeLiquidity(eth)).to.be.revertedWith("Not enough LP")
        })
      })

      describe("Check conditions in addLiquidity()", function() {
        it("Error when add liq with different amount of astr tokens", async function() {
          await user1Ntoken.approve(adapter.address, eth)
          await expect(user1Adapter.addLiquidity([eth, eth], false, {value: "1"})).to.be.revertedWith("Value need to be equal to amount of ASTR tokens")
        })
  
        it("Error when zero amount of tokens added", async function() {
          await user1Ntoken.approve(adapter.address, eth)
          await expect(user1Adapter.addLiquidity(["0", "0"], false, {value: "0"})).to.be.revertedWith("Amount of tokens should be greater than zero")
        })
  
        it("Error when more than two tokens in array", async function() {
          await user1Ntoken.approve(adapter.address, eth)
          await expect(user1Adapter.addLiquidity(["1", "1", "1"], false, {value: "1"})).to.be.revertedWith("The length of amounts must be equal to two")
        })
      })

      describe("Check balances", async function () {
        it("Balance of user1 should be equal to 100", async function () {
          const contract = new ethers.Contract(nastr.address, abiERC20, ethers.provider)
          expect(await contract.balanceOf(user1.address)).to.equal(ethers.utils.parseEther("100"));
        })

        it("Balance of user2 should be equal to 100", async function () {
          const contract = new ethers.Contract(nastr.address, abiERC20, ethers.provider)
          expect(await contract.balanceOf(user2.address)).to.equal(ethers.utils.parseEther("100"));
        })
      })

      describe("Try to renounce ownership", function () {
        it("Attempt", async function () {
          await expect(ownerAdapter.renounceOwnership()).to.be.revertedWith("It is not possible to renounce ownership")
        })
      })

      describe("Testing totalReserves()", function () {
        it("Add liquidity to pool by user1", async function () {
          await user1Ntoken.approve(adapter.address, eth)
          await user1Adapter.addLiquidity([eth, eth], true, { value: eth })
        })

        it("Check total reserves", async function () {
          expect(await user1Adapter.totalReserves()).to.be.eq(ethers.utils.parseEther("202"))
        })
      })

      describe("Check calc() function and receiving 'second amount'", function () {
        it("Add liquidity with false", async function () {
          await user1Ntoken.approve(adapter.address, eth)
          const lpBalBefore = await adapterInst.lpBalances(user1.address)
          await user1Adapter.addLiquidity([eth, eth], false, { value: eth })
          const lpBalAfter = await adapterInst.lpBalances(user1.address)
          expect(lpBalAfter - lpBalBefore).to.be.gt(0)
        })

        it("Testing getSecondAmount()", async function () {
          expect(await user1Adapter.getSecondAmount(eth, true)).to.be.gt(0)
          expect(await user1Adapter.getSecondAmount(eth, false)).to.be.gt(0)
        })

        it("Check return value from calc()", async function () {
          expect(await user1Adapter.calc(user1.address)).to.be.eq(ethers.utils.parseEther("2"))
        })

        it("Testing technical function gaugeBalances()", async function () {
          const depositedByUser = await adapterInst.depositedLp(user1.address)
          const gaugeBalance = await adapterInst.gaugeBalances(user1.address)
          expect(depositedByUser).to.be.eq(gaugeBalance)
        })
      })

      describe("Add and remove liquidity for user1", function () {
        it("Add liquidity with true", async function () {
          const depositedLpBefore = await adapterInst.depositedLp(user1.address)
          await user1Ntoken.approve(adapter.address, eth)
          await expect(user1Adapter.addLiquidity([eth, eth], true, { value: eth }))
          .to.emit(adapterInst, "AddLiquidity").withArgs(user1.address, eth, eth, true, eth)
          const depositedLpAfter = await adapterInst.depositedLp(user1.address)
          expect(depositedLpAfter - depositedLpBefore).to.be.gt(0)
        })

        it("Withdraw LP tokens with true", async function () {
          const balBefore = await ethers.provider.getBalance(user1.address)
          const depositedLp = await adapterInst.depositedLp(user1.address)
          await user1Adapter.withdrawLP(depositedLp, true)
          const balAfter = await ethers.provider.getBalance(user1.address)
          expect(balAfter - balBefore).to.be.gt(0)
        })
      })

      describe("Testing add LP function", function () {
        it("Mint LP for user1", async function () {
          const balBefore = await lpInst.balanceOf(user1.address)
          await user1Lp.mint(user1.address, ethers.utils.parseEther("10"))
          const balAfter = await lpInst.balanceOf(user1.address)
          expect(balAfter - balBefore).to.be.eq(parseInt(ethers.utils.parseEther("10")))
        })

        it("Add LP by user1 with autoDeposit == false", async function () {
          const lpBalBefore = await adapterInst.lpBalances(user1.address)
          await user1Lp.approve(adapter.address, ethers.utils.parseEther("5"))
          await user1Adapter.addLp((ethers.utils.parseEther("5")), false)
          const lpBalAfter = await adapterInst.lpBalances(user1.address)
          expect(lpBalAfter - lpBalBefore).to.be.eq(parseInt(ethers.utils.parseEther("5")))
        })

        it("Add LP by user1 with autoDeposit == true", async function () {
          const lpBalBefore = await adapterInst.lpBalances(user1.address)
          const depositedLpBefore = await adapterInst.depositedLp(user1.address)
          await user1Lp.approve(adapter.address, ethers.utils.parseEther("5"))
          await user1Adapter.addLp(ethers.utils.parseEther("5"), true)
          const lpBalAfter = await adapterInst.lpBalances(user1.address)
          const depositedLpAfter = await adapterInst.depositedLp(user1.address)
          expect(lpBalAfter - lpBalBefore).to.be.eq(0)
          expect(depositedLpAfter - depositedLpBefore).to.be.eq(parseInt(ethers.utils.parseEther("5")))
        })
      })

      describe("Check reward receiving", function () {
        it("add liquidity with true", async function () {
          const stakedBalBefore = await adapterInst.depositedLp(user1.address)
          await user1Ntoken.approve(adapter.address, eth)
          await user1Adapter.addLiquidity([eth, eth], true, { value: eth })
          const stakedBalAfter = await adapterInst.depositedLp(user1.address)

          expect(stakedBalAfter - stakedBalBefore).to.be.gt(0)
        })

        it("three blocks later", async function () {
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
        })

        it("add more liquidity with true", async function () {
          const stakedBalBefore = await adapterInst.depositedLp(user1.address)
          await user1Ntoken.approve(adapter.address, eth)
          await user1Adapter.addLiquidity([eth, eth], true, { value: eth })
          const stakedBalAfter = await adapterInst.depositedLp(user1.address)

          expect(stakedBalAfter - stakedBalBefore).to.be.gt(0)
        })

        it("check totalStaked in farm", async function () {
          expect(await farmInst.totalStaked()).to.be.gt(0)
        })
      })

      describe("Testing addLiquidity function", function () {
        it("Adding liquidity with _autoStake = false", async function () {
          await user1Ntoken.approve(adapter.address, eth)

          const adapterBalanceBefore = await ethers.provider.getBalance(adapter.address)
          const adapterLpBalanceBefore = await lpInst.balanceOf(adapter.address)
          const poolBalanceBefore = await ethers.provider.getBalance(pool.address)

          await user1Adapter.addLiquidity([eth, eth], false, { value: eth })

          const adapterBalanceAfter = await ethers.provider.getBalance(adapter.address)
          const adapterBalanceLpAfter = await lpInst.balanceOf(adapter.address)
          const poolBalanceAfter = await ethers.provider.getBalance(pool.address)

          expect(adapterBalanceAfter).to.be.equal(adapterBalanceBefore)
          expect(adapterBalanceLpAfter - adapterLpBalanceBefore).not.to.be.equal(0)
          expect(poolBalanceAfter - poolBalanceBefore).to.be.equal(parseInt(eth))
        })

        it("Adding liquidity with _autoStake = true", async function () {
          await user1Ntoken.approve(adapter.address, eth)

          const adapterBalanceBefore = await ethers.provider.getBalance(adapter.address)
          const adapterLpBalanceBefore = await lpInst.balanceOf(adapter.address)
          const poolBalanceBefore = await ethers.provider.getBalance(pool.address)
          const adapterTotalStakedBalanceBefore = await adapterInst.totalStakedLp()

          await user1Adapter.addLiquidity([eth, eth], true, { value: eth })

          const adapterBalanceAfter = await ethers.provider.getBalance(adapter.address)
          const adapterLpBalanceAfter = await lpInst.balanceOf(adapter.address)
          const poolBalanceAfter = await ethers.provider.getBalance(pool.address)
          const adapterTotalStakedBalanceAfter = await adapterInst.totalStakedLp()

          expect(adapterBalanceAfter).to.be.equal(adapterBalanceBefore)
          expect(adapterLpBalanceAfter).to.be.equal(adapterLpBalanceBefore)
          expect(parseInt(ethers.utils.formatUnits(poolBalanceAfter, 0) - ethers.utils.formatUnits(poolBalanceBefore, 0))).to.be.equal(parseInt(eth))
          expect(parseInt(adapterTotalStakedBalanceAfter - adapterTotalStakedBalanceBefore)).to.be.equal(parseInt(eth))
        })
      })

      describe("Adding liquidity and receiving rewards for one user", function () {

        it("User1 added liquidity with flag 'true'. User1 staked bal increased. Total staked increased. Adapter staked bal increased", async function () {
          const stakedBalanceBefore = await user1Adapter.depositedLp(user1.address)
          await user1Ntoken.approve(adapter.address, eth)
          await user1Adapter.addLiquidity([eth, eth], true, { value: eth })
          const stakedBalanceAfter = await user1Adapter.depositedLp(user1.address)
          expect(stakedBalanceAfter - stakedBalanceBefore).to.be.equal(parseInt(eth))
          expect(await user1Adapter.totalStakedLp()).to.be.gt(0)
        })

        it("Three blocks later...", async function () {
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
        })

        it("Check if there is rewards for adapter was increased", async function () {
          expect(await farmInst.pendingARSW("26", user1.address)).to.be.gt(0)
        })

        it("User1 added liq second time with same values. At this time flag 'false'. User1 lp bal inreased, gauge bal the same", async function () {
          await ethers.provider.send('evm_mine');
          const gaugeBalanceBefore = await user1Adapter.depositedLp(user1.address)
          const lpBalBefore = await user1Adapter.lpBalances(user1.address)
          await user1Ntoken.approve(adapter.address, eth)
          await user1Adapter.addLiquidity([eth, eth], false, { value: eth })
          const gaugeBalanceAfter = await user1Adapter.depositedLp(user1.address)
          const lpBalAfter = await user1Adapter.lpBalances(user1.address)
          expect(gaugeBalanceAfter - gaugeBalanceBefore).to.be.equal(0)
          expect(lpBalAfter - lpBalBefore).to.be.equal(parseInt(eth))
        })

        it("User1 deposit LP. His deposited bal was increased. Adapter deposited bal increased", async function () {
          const amountLP = await user1Adapter.lpBalances(user1.address)
          const depositedBalBefore = await user1Adapter.depositedLp(user1.address)
          const adapterDepositedBalBefore = await adapterInst.totalStakedLp()
          const accRewsPerShareBefore = await adapterInst.accumulatedRewardsPerShare()
          await user1Adapter.depositLP(amountLP)
          const adapterDepositedBalAfter = await adapterInst.totalStakedLp()
          const depositedBalAfter = await user1Adapter.depositedLp(user1.address)
          const accRewsPerShareAfter = await adapterInst.accumulatedRewardsPerShare()
          expect(depositedBalAfter - depositedBalBefore).to.be.equal(parseInt(ethers.utils.formatUnits(amountLP, 0)))
          expect(adapterDepositedBalAfter - adapterDepositedBalBefore).to.be.equal(parseInt(ethers.utils.formatUnits(amountLP, 0)))
          expect(accRewsPerShareAfter - accRewsPerShareBefore).to.be.gt(0)
        })

        it("Amount of rewards for user1 was increased", async function () {
          expect(await user1Adapter.rewards(user1.address)).to.be.gt(0)
        })

        it("Check pendingRewards", async function () {
          expect(await user1Adapter.pendingRewards(user1.address)).to.be.gt(0)
        })

        it("Withdraw LP by user1 and using pendingRewards, check second condition", async function() {
          const depositedLp = await user1Adapter.depositedLp(user1.address)
          await user1Adapter.withdrawLP(depositedLp, false)
          expect(await user1Adapter.pendingRewards(user1.address)).to.be.gt(0)
        })

        it("User1 has successfully claimed his rewards", async function () {
          const rewardsAmountTotal = await user1Adapter.rewards(user1.address)
          const rewards = rewardsAmountTotal - rewardsAmountTotal * 0.1
          const arswBalBefore = await arswInst.balanceOf(user1.address)
          await user1Adapter.claim()
          const arswBalAfter = await arswInst.balanceOf(user1.address)
          expect(arswBalAfter - arswBalBefore).to.be.eq(rewards)
        })
      })

      describe("Check if the founded after audit issue QSP-1 was solved", function () {
        it("User1 added liquidity with flag 'true", async function () {
          const depositedBefore = await adapterInst.depositedLp(user1.address)
          await user1Ntoken.approve(adapter.address, eth)
          await user1Adapter.addLiquidity([eth, eth], true, { value: eth })
          const depositedAfter = await adapterInst.depositedLp(user1.address)

          expect(depositedAfter - depositedBefore).to.be.gt(0)
        })

        it("Three blocks later...", async function () {
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
        })

        it("User2 added liquidity with flag 'true'", async function () {
          const depositedBefore = await adapterInst.depositedLp(user2.address)
          await user2Ntoken.approve(adapter.address, eth)
          await user2Adapter.addLiquidity([eth, eth], true, { value: eth })
          const depositedAfter = await adapterInst.depositedLp(user2.address)

          expect(depositedAfter - depositedBefore).to.be.gt(0)
        })

        it("User1 has claimed his rewards. His arsw balance was increased", async function () {
          const rewardsAmountTotal = await user1Adapter.rewards(user1.address)
          const rewards = rewardsAmountTotal - rewardsAmountTotal * 0.1
          const arswBalBefore = await arswInst.balanceOf(user1.address)
          await user1Adapter.claim()
          const arswBalAfter = await arswInst.balanceOf(user1.address)
          expect(arswBalAfter - arswBalBefore).to.be.gt(rewards)
        })

        it("Three blocks later...", async function () {
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
          await ethers.provider.send('evm_mine');
        })

        it("Check adapter rewards", async function () {
          expect(await farmInst.rewards(adapter.address)).to.be.eq(0)
        })

        it("User2 withdraw some deposited lp", async function () {
          await user2Adapter.withdrawLP(eth, false)
        })

        it("Check adapter rewards", async function () {
          expect(await farmInst.rewards(adapter.address)).to.be.eq(0)
        })

        it("User2 remove some liquidity", async function () {
          await user2Adapter.removeLiquidity(eth)
        })

        it("User2 has claimed his rewards. His arsw balance was increased", async function () {
          const rewardsAmountTotal = await user2Adapter.rewards(user2.address)
          const rewards = rewardsAmountTotal - rewardsAmountTotal * 0.1
          const arswBalBefore = await arswInst.balanceOf(user2.address)
          await user2Adapter.claim()
          const arswBalAfter = await arswInst.balanceOf(user2.address)
          expect(arswBalAfter - arswBalBefore).to.be.eq(rewards)
        })

        it("Withdraw revenue by owner", async function () {
          const revenueTotal = await adapterInst.revenuePool();
          const arswBalanceBefore = await arswInst.balanceOf(owner.address)
          await ownerAdapter.withdrawRevenue(revenueTotal)
          const arswBalanceAfter = await arswInst.balanceOf(owner.address)
          expect(arswBalanceAfter - arswBalanceBefore).to.be.equal(parseInt(revenueTotal))
        })
      })
    }

  });
}

const abiERC20 = [
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "symbol",
        "type": "string"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "owner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "value",
        "type": "uint256"
      }
    ],
    "name": "Approval",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "value",
        "type": "uint256"
      }
    ],
    "name": "Transfer",
    "type": "event"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "owner",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      }
    ],
    "name": "allowance",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "eth",
        "type": "uint256"
      }
    ],
    "name": "approve",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "account",
        "type": "address"
      }
    ],
    "name": "balanceOf",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [
      {
        "internalType": "uint8",
        "name": "",
        "type": "uint8"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "subtractedValue",
        "type": "uint256"
      }
    ],
    "name": "decreaseAllowance",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "spender",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "addedValue",
        "type": "uint256"
      }
    ],
    "name": "increaseAllowance",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "receiver",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "eth",
        "type": "uint256"
      }
    ],
    "name": "mint",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "name",
    "outputs": [
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [
      {
        "internalType": "string",
        "name": "",
        "type": "string"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalSupply",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "eth",
        "type": "uint256"
      }
    ],
    "name": "transfer",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "from",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "eth",
        "type": "uint256"
      }
    ],
    "name": "transferFrom",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
const abiPool = [
  {
    "inputs": [
      {
        "internalType": "contract MockERC20",
        "name": "_lp",
        "type": "address"
      },
      {
        "internalType": "contract MockERC20",
        "name": "_nastr",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "amountTokenDesired",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amountTokenMin",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amountETHMin",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "deadline",
        "type": "uint256"
      }
    ],
    "name": "addLiquidityETH",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "amountToken",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amountETH",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "liquidity",
        "type": "uint256"
      }
    ],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "lp",
    "outputs": [
      {
        "internalType": "contract MockERC20",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "nastr",
    "outputs": [
      {
        "internalType": "contract MockERC20",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "amountA",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "reserveA",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "reserveB",
        "type": "uint256"
      }
    ],
    "name": "quote",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "amountB",
        "type": "uint256"
      }
    ],
    "stateMutability": "pure",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "token",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "liquidity",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amountTokenMin",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amountETHMin",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "deadline",
        "type": "uint256"
      }
    ],
    "name": "removeLiquidityETH",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "amountToken",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amountETH",
        "type": "uint256"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "reservesN",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "reservesT",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
const abiFarm = [
  {
    "inputs": [
      {
        "internalType": "contract MockERC20",
        "name": "_arsw",
        "type": "address"
      },
      {
        "internalType": "contract MockERC20",
        "name": "_lp",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "REWARDS_PRECISION",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "accRewsPerShare",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "arsw",
    "outputs": [
      {
        "internalType": "contract MockERC20",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "pid",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "deposit",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "pid",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "harvest",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "lastBlock",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "lp",
    "outputs": [
      {
        "internalType": "contract MockERC20",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "pid",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "user",
        "type": "address"
      }
    ],
    "name": "pendingARSW",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "rewardDebt",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "rewards",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "stakedByUser",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalStaked",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "pid",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "to",
        "type": "address"
      }
    ],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
const abiPair = [
  {
    "inputs": [
      {
        "internalType": "contract MockArthswapRouter",
        "name": "_pool",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "inputs": [],
    "name": "getReserves",
    "outputs": [
      {
        "internalType": "uint112",
        "name": "reserve0",
        "type": "uint112"
      },
      {
        "internalType": "uint112",
        "name": "reserve1",
        "type": "uint112"
      },
      {
        "internalType": "uint32",
        "name": "blockTimestampLast",
        "type": "uint32"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pool",
    "outputs": [
      {
        "internalType": "contract MockArthswapRouter",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
const abiAdapter = [
  {
    "inputs": [],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "user",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "astrAmount",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "nastrAmount",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "bool",
        "name": "autoStake",
        "type": "bool"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "lpAmount",
        "type": "uint256"
      }
    ],
    "name": "AddLiquidity",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "user",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "Claim",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "DepositLP",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "user",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "rewardsToHarvest",
        "type": "uint256"
      }
    ],
    "name": "HarvestRewards",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "uint8",
        "name": "version",
        "type": "uint8"
      }
    ],
    "name": "Initialized",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousOwner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "user",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amountLP",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "receivedASTR",
        "type": "uint256"
      }
    ],
    "name": "RemoveLiquidity",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "user",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "bool",
        "name": "autoWithdraw",
        "type": "bool"
      }
    ],
    "name": "WithdrawLP",
    "type": "event"
  },
  {
    "inputs": [],
    "name": "REVENUE_FEE",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "SLIPPAGE_CONTROL",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "accumulatedRewardsPerShare",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256[]",
        "name": "_amounts",
        "type": "uint256[]"
      },
      {
        "internalType": "bool",
        "name": "_autoStake",
        "type": "bool"
      }
    ],
    "name": "addLiquidity",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "_autoDeposit",
        "type": "bool"
      }
    ],
    "name": "addLp",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "arswToken",
    "outputs": [
      {
        "internalType": "contract IERC20Upgradeable",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_user",
        "type": "address"
      }
    ],
    "name": "calc",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "nShare",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      }
    ],
    "name": "calculateRemoveLiquidity",
    "outputs": [
      {
        "internalType": "uint256[]",
        "name": "",
        "type": "uint256[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "claim",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      }
    ],
    "name": "depositLP",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "depositedLp",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "farm",
    "outputs": [
      {
        "internalType": "contract IMasterChef",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_user",
        "type": "address"
      }
    ],
    "name": "gaugeBalances",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getAPR",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "_isAstr",
        "type": "bool"
      }
    ],
    "name": "getSecondAmount",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "sum",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "contract IMasterChef",
        "name": "_farm",
        "type": "address"
      },
      {
        "internalType": "contract IPancakeRouter01",
        "name": "_pool",
        "type": "address"
      },
      {
        "internalType": "contract IERC20Upgradeable",
        "name": "_nToken",
        "type": "address"
      },
      {
        "internalType": "contract IERC20Upgradeable",
        "name": "_lp",
        "type": "address"
      },
      {
        "internalType": "contract IPancakePair",
        "name": "_pair",
        "type": "address"
      },
      {
        "internalType": "contract IERC20Upgradeable",
        "name": "_arswToken",
        "type": "address"
      },
      {
        "internalType": "uint256",
        "name": "_pid",
        "type": "uint256"
      }
    ],
    "name": "initialize",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "lp",
    "outputs": [
      {
        "internalType": "contract IERC20Upgradeable",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "lpBalances",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "nToken",
    "outputs": [
      {
        "internalType": "contract IERC20Upgradeable",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pair",
    "outputs": [
      {
        "internalType": "contract IPancakePair",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_user",
        "type": "address"
      }
    ],
    "name": "pendingRewards",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "sum",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pool",
    "outputs": [
      {
        "internalType": "contract IPancakeRouter01",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      }
    ],
    "name": "removeLiquidity",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "renounceOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "revenuePool",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "rewardDebt",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "name": "rewards",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalReserves",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "sum",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "totalStakedLp",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "transferOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      },
      {
        "internalType": "bool",
        "name": "_autoWithdraw",
        "type": "bool"
      }
    ],
    "name": "withdrawLP",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_amount",
        "type": "uint256"
      }
    ],
    "name": "withdrawRevenue",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "stateMutability": "payable",
    "type": "receive"
  }
]