//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./MockERC20.sol";

contract MockArthswapMasterChef {
    MockERC20 public arsw;
    MockERC20 public lp;

    uint256 public accRewsPerShare;
    uint256 public lastBlock;
    uint256 public totalStaked;
    uint256 public constant REWARDS_PRECISION = 1e12;
    
    mapping(address => uint256) public stakedByAdapter;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public rewards;

    constructor(
        MockERC20 _arsw,
        MockERC20 _lp
    ) {
        arsw = _arsw;
        lp = _lp;
        lastBlock = block.number;
    }

    // function harvestRewards() private {
    //     updatePoolRewards();
        
    //     uint256 rewardsToHarvest = accRewsPerShare * stakedByAdapter[msg.sender] / REWARDS_PRECISION - rewardDebt[msg.sender];
    //     rewardDebt[msg.sender] = accRewsPerShare * stakedByAdapter[msg.sender] / REWARDS_PRECISION;
    //     if (rewardsToHarvest == 0) {
    //         rewardDebt[msg.sender] = accRewsPerShare * stakedByAdapter[msg.sender] / REWARDS_PRECISION;
    //         return;
    //     }
    //     rewardDebt[msg.sender] = accRewsPerShare * stakedByAdapter[msg.sender] / REWARDS_PRECISION;
    //     rewards[msg.sender] += rewardsToHarvest;
    // }

    // function updatePoolRewards() private {
    //     uint256 receivedRewards = (block.number - lastBlock) * 1_000_000_000;

    //     if (totalStaked == 0) {
    //         lastBlock = block.number;
    //         return;
    //     }

    //     accRewsPerShare += receivedRewards * REWARDS_PRECISION / totalStaked;
    //     lastBlock = block.number;
    // }

    function deposit(uint256 pid, uint256 amount, address to) external {
        lp.transferFrom(msg.sender, address(this), amount);
        stakedByAdapter[msg.sender] += amount;
        totalStaked += amount;
    }

    function withdraw(uint256 pid, uint256 amount, address to) external {
        require(lp.balanceOf(address(this)) >= amount, "Not enough LP on farm contract");
        stakedByAdapter[msg.sender] -= amount;
        totalStaked -= amount;
        lp.transfer(msg.sender, amount);
    }

    function pendingARSW(uint256 pid, address user) external view returns (uint256) {
        return (block.number - lastBlock) * 1e9;
    }

    function harvest(uint256 pid, address to) external {
        require(block.number > lastBlock, "There is no any rewards");
        uint256 rewardsToHarvest = (block.number - lastBlock) * 1e9;
        lastBlock = block.number;
        arsw.mint(msg.sender, rewardsToHarvest);
    }
}
