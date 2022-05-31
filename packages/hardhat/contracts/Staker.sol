//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./LiquidStaking.sol";
import "./interfaces/DappsStaking.sol";


contract Staker is Initializable{

    DappsStaking public constant DAPPS_STAKING = DappsStaking(0x0000000000000000000000000000000000005001);    

    uint256 public revenue;
    uint256 public rewards;
    address public staker;
    address public LiquidStakingAddr;
    LiquidStaking lsc;

    mapping(uint256 => uint256) eraStaked;
    mapping(uint256 => uint256) eraUnstaked;
    mapping(uint256 => uint256) eraReward;

    function initialize(address _staker, address _lsAddr) public initializer {
        staker = _staker;
        LiquidStakingAddr = _lsAddr;
        lsc = LiquidStaking(LiquidStakingAddr);
        DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance);
    }

    function stake(uint256 era) public payable {
        uint256 val = lsc.eraStaked(era);
        require(msg.value == val, "Invalid value!");
        DAPPS_STAKING.bond_and_stake(LiquidStakingAddr, uint128(val));
    }

    function unstake(uint256 era) public {
        uint256 val = lsc.eraUnstaked(era);
        DAPPS_STAKING.unbond_and_unstake(LiquidStakingAddr, uint128(val));
    }

    function claimDapp(uint128 era) public {
        uint256 prevBalance = address(this).balance;
        DAPPS_STAKING.claim_dapp(LiquidStakingAddr, era);
        uint256 newBalance = address(this).balance;
        uint256 rev  = (newBalance - prevBalance) / 100 * 10; // 10% of reward
        revenue += rev;
        payable(msg.sender).call{value: newBalance - prevBalance - rev};
    }

    function claimUser() public {
        uint256 prevBalance = address(this).balance;
        DAPPS_STAKING.claim_staker(LiquidStakingAddr);
        uint256 newBalance = address(this).balance;
        uint256 rev = (newBalance - prevBalance) / 100 * 10; // 10% of reward
        revenue += rev;
        rewards += newBalance - prevBalance - rev;
    }

    function fillRewards() public {
        require(rewards > 0, "No rewards claimed!");
        lsc.fillRewardsPool{value: rewards}();
        rewards = 0;
    }

    function fillUnstaking() public {
        require(revenue > 0, "Empty revenue!");
        lsc.fillUnstakingPool{value: revenue}();
        revenue = 0;
    }

    function withdraw() public {
        uint256 prevBalance = address(this).balance;
        DAPPS_STAKING.withdraw_unbonded();
        uint256 newBalance = address(this).balance;
        revenue += newBalance - prevBalance;
    }
}