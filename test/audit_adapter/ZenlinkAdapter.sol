const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { connect } = require("http2");

/*
 * @title:   ZenlinkAdapter test script
 * @author:  Aleksey Zhelyabin
*/

const metadataERC20 = require('../artifacts/contracts/mock/MockERC20.sol/MockERC20.json')
const metadataPool = require('../artifacts/contracts/mock/MockZenlinkRouter.sol/MockZenlinkRouter.json')
const metadataFarm = require('../artifacts/contracts/mock/MockZenlinkMasterChef.sol/MockZenlinkMasterChef.json')
const metadataPair = require('../artifacts/contracts/mock/MockZenlinkPair.sol/MockZenlinkPair.json')
const metadataAdapter = require('../artifacts/contracts/ZenlinkAdapter.sol/ZenlinkAdapter.json')

if (true) {
  describe("ZenlinkAdapter", function () {
    // users vars
    let owner, user1, user2

    // contracts vars
    let nastr, lp, zlk, pool, farm, pair, adapter

    // instances
    let nastrInst, lpInst, zlkInst, poolInst, farmInst, pairInst, adapterInst

    // connected users
    let user1Adapter, user1Ntoken, user1ZLKToken, user1Farm, user1Pair, user2Adapter, user2Ntoken, user2ZLKToken, user2Farm, user2Pair

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
      const ZlkLpFactory = await ethers.getContractFactory("MockERC20");
      const Factory = await ethers.getContractFactory("MockERC20");
      const ZlkFactory = await ethers.getContractFactory("MockERC20");

      // Arthswap contracts
      const PoolFactory = await ethers.getContractFactory("MockZenlinkRouter");
      const FarmFactory = await ethers.getContractFactory("MockZenlinkMasterChef");
      const PairFactory = await ethers.getContractFactory("MockZenlinkPair");
      const AdapterFactory = await ethers.getContractFactory("ZenlinkAdapter")

      // deploy contracts
      nastr = await NastrFactory.deploy("nASTR", "nASTR token")
      lp = await ZlkLpFactory.deploy("LP", "LP token")
      zlk = await ZlkFactory.deploy("ZLK", "ZLK token")
      pool = await PoolFactory.deploy(lp.address, nastr.address)
      farm = await FarmFactory.deploy(zlk.address, lp.address)
      pair = await PairFactory.deploy(pool.address, lp.address)
      adapter = await upgrades.deployProxy(AdapterFactory, [
        farm.address,
        pool.address,
        nastr.address,
        lp.address,
        pair.address,
        zlk.address,
        "26"
      ])

      // set instances
      nastrInst = new ethers.Contract(nastr.address, metadataERC20.abi, ethers.provider)
      lpInst = new ethers.Contract(lp.address, metadataERC20.abi, ethers.provider)
      zlkInst = new ethers.Contract(zlk.address, metadataERC20.abi, ethers.provider)
      poolInst = new ethers.Contract(pool.address, metadataPool.abi, ethers.provider)
      farmInst = new ethers.Contract(farm.address, metadataFarm.abi, ethers.provider)
      pairInst = new ethers.Contract(pair.address, metadataPair.abi, ethers.provider)
      adapterInst = new ethers.Contract(adapter.address, metadataAdapter.abi, ethers.provider)

      // connected users
      ownerAdapter = adapterInst.connect(owner)

      user1Adapter = adapterInst.connect(user1)
      user1Ntoken = nastrInst.connect(user1)
      user1ZLKToken = zlkInst.connect(user1)
      user1Farm = farmInst.connect(user1)
      user1Pair = pairInst.connect(user1)
      user1Lp = lpInst.connect(user1)

      user2Adapter = adapterInst.connect(user2)
      user2Ntoken = nastrInst.connect(user2)
      user2ZLKToken = zlkInst.connect(user2)
      user2Farm = farmInst.connect(user2)
      user2Pair = pairInst.connect(user2)

      // mint tokens to users
      const deployerNastr = new ethers.Contract(nastr.address, metadataERC20.abi, owner)
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
      it("Error when not enough ZLK", async function() {
        await expect(ownerAdapter.withdrawRevenue(ethers.utils.parseEther("100")))
        .to.be.revertedWith("Not enough ZLK revenue")
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
          expect(await farmInst.pendingZLK("26", user1.address)).to.be.gt(0)
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
          const zlkBalBefore = await zlkInst.balanceOf(user1.address)
          await user1Adapter.claim()
          const zlkBalAfter = await zlkInst.balanceOf(user1.address)
          expect(zlkBalAfter - zlkBalBefore).to.be.eq(rewards)
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

        it("User1 has claimed his rewards. His zlk balance was increased", async function () {
          const rewardsAmountTotal = await user1Adapter.rewards(user1.address)
          const rewards = rewardsAmountTotal - rewardsAmountTotal * 0.1
          const zlkBalBefore = await zlkInst.balanceOf(user1.address)
          await user1Adapter.claim()
          const zlkBalAfter = await zlkInst.balanceOf(user1.address)
          expect(zlkBalAfter - zlkBalBefore).to.be.gt(rewards)
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

        it("User2 has claimed his rewards. His zlk balance was increased", async function () {
          const rewardsAmountTotal = await user2Adapter.rewards(user2.address)
          const rewards = rewardsAmountTotal - rewardsAmountTotal * 0.1
          const zlkBalBefore = await zlkInst.balanceOf(user2.address)
          await user2Adapter.claim()
          const zlkBalAfter = await zlkInst.balanceOf(user2.address)
          expect(zlkBalAfter - zlkBalBefore).to.be.eq(rewards)
        })

        it("Withdraw revenue by owner", async function () {
          const revenueTotal = await adapterInst.revenuePool();
          const zlkBalanceBefore = await zlkInst.balanceOf(owner.address)
          await ownerAdapter.withdrawRevenue(revenueTotal)
          const zlkBalanceAfter = await zlkInst.balanceOf(owner.address)
          expect(zlkBalanceAfter - zlkBalanceBefore).to.be.equal(parseInt(revenueTotal))
        })
      })
    }

  });
}
