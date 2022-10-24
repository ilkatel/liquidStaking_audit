//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./MockERC20.sol";

contract MockZenlinkMasterChef {
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

    function stake(uint256 pid,  address to, uint256 amount) external {
        lp.transferFrom(msg.sender, address(this), amount);
        stakedByAdapter[msg.sender] += amount;
        totalStaked += amount;
    }

    function redeem(uint256 pid, address to, uint256 amount) external {
        require(lp.balanceOf(address(this)) >= amount, "Not enough LP on farm contract");
        stakedByAdapter[msg.sender] -= amount;
        totalStaked -= amount;
        lp.transfer(msg.sender, amount);
    }

    function pendingRewards(uint256 pid, address user) external view returns (uint256[] memory, uint256) {
        uint256[] memory arr = new uint256[](2);
        arr[0] = (block.number - lastBlock) * 1e9;
        return (arr, 0);
    }

    function claim(uint256 pid) external {
        require(block.number > lastBlock, "There is no any rewards");
        uint256 rewardsToHarvest = (block.number - lastBlock) * 1e9;
        lastBlock = block.number;
        arsw.mint(msg.sender, rewardsToHarvest);
    }
}
