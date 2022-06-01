//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/DappsStaking.sol";
import "./nDistributor.sol";
/*
inside one era:
staker/dapp rewards claimed
pools filled
stakes/unstakes accepted
bond/unbond called
*/
contract LiquidStaking is Initializable {
    DappsStaking public constant DAPPS_STAKING = DappsStaking(0x0000000000000000000000000000000000005001);    

    string public utilName;
    string public DNTname;
    uint256 minStake;
    uint256 withdrawBlock;

    uint256 unstakingPool;
    uint256 rewardPool;

    address public distrAddr;
    NDistributor   distr;

    struct Stake {
        uint256 totalBalance;
        uint256 eraStarted;
    }
    mapping(address => Stake) public stakes;

    struct Withdrawal {
        uint256 val;
        uint256 eraReq;
    }
    mapping(address => Withdrawal[]) public withdrawals;

    struct eraData {
        bool done;
        uint256 val;
    }
    mapping(uint256 => eraData) public eraStaked; // total tokens staked per era
    mapping(uint256 => eraData) public eraUnstaked; // total tokens unstaked per era
    mapping(uint256 => eraData) public eraStakerReward; // total staker rewards per era
    mapping(uint256 => eraData) public eraDappReward; // total dapp rewards per era
    mapping(uint256 => eraData) public eraRevenue; // total revenue per era

    function initialize() public initializer {
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();
        DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance);
    }


    // ADMIN FUNCS
    function set_distr(address _newDistr) public {
        distrAddr = _newDistr;
        distr = NDistributor(distrAddr);
    }

    function set_min(uint256 _val) public {
        minStake = _val;
    }

    function current_era() public view returns(uint256) {
        return DAPPS_STAKING.read_current_era();
    }


    // GLOBAL FUNCS
    function global_stake(uint256 _era) external {
        eraData storage d = eraStaked[_era];

        require(!d.done, "Already done!");

        d.done = true;

        DAPPS_STAKING.bond_and_stake(address(this), uint128(d.val));
    }

    function global_unstake(uint256 _era) external {
        eraData storage d = eraUnstaked[_era];

        require(!d.done, "Already done!");

        d.done = true;

        DAPPS_STAKING.unbond_and_unstake(address(this), uint128(d.val));
    }

    function global_withdraw() external {
        uint256 p = address(this).balance;
        DAPPS_STAKING.withdraw_unbonded();
        uint256 a = address(this).balance;
        unstakingPool += a - p;
    }

    function claim_dapp(uint256 _era) external {
        require(current_era() != _era, "Cannot claim yet!");
        require(eraDappReward[_era].val == 0, "Already claimed!");
        uint256 p = address(this).balance;
        DAPPS_STAKING.claim_dapp(address(this), uint128(_era));
        uint256 a = address(this).balance;
        eraDappReward[_era].val = a - p;
        eraRevenue[_era].val += eraDappReward[_era].val / 100 * 10; // 10% goes to revenue pool
    }

    function claim_user(uint256 _era) external {
        uint256 p = address(this).balance;
        DAPPS_STAKING.claim_staker(address(this));
        uint256 a = address(this).balance;
        eraStakerReward[_era].val = a - p;
        eraRevenue[_era].val += eraStakerReward[_era].val / 100; // 1% goes to revenue pool
    }

    function fill_pools(uint256 _era) external {
        require(!eraRevenue[_era].done, "Already done!");
        require(!eraStakerReward[_era].done, "Already done!");
        eraRevenue[_era].done = true;
        eraStakerReward[_era].done = true;
        unstakingPool += eraRevenue[_era].val / 100 * 10; // 10% of revenue goes to unstaking pool
        rewardPool += eraStakerReward[_era].val;
    }


    // USER FUNCS
    function stake() external payable {
        Stake storage s = stakes[msg.sender];
        uint256 era = current_era();

        require(msg.value > minStake, "Send at least min stake value!");

        eraStaked[era].val += msg.value;

        s.totalBalance += msg.value;
        s.eraStarted = s.eraStarted == 0 ? era : s.eraStarted;
        distr.issueDnt(msg.sender, msg.value, utilName, DNTname);
    }

    function unstake(uint256 _amount, bool _immediate) external {
        Stake storage s = stakes[msg.sender];
        uint256 era = current_era();
        require(_amount > 0, "Invalid amount!");
        require(s.totalBalance >= _amount, "Invalid amount!");

        eraUnstaked[era].val += _amount;

        s.totalBalance -= _amount;
        if(s.totalBalance == 0) {
            s.eraStarted = 0;
        }

        if (_immediate) {
            uint256 fee = _amount / 100; // 1% immediate unstaking fee
            eraRevenue[era].val += fee;
            distr.removeDnt(msg.sender, _amount, utilName, DNTname);
            payable(msg.sender).call{value: _amount - fee};
        } else {
            withdrawals[msg.sender].push(Withdrawal({
                val: _amount,
                eraReq: era
            }));
            // create withdrawal to pay later
        }
    }

    function claim() external {
        /* 
        send reward to user from rewards pool according to their share
        */
    }

    function withdraw(uint256 _id) external {
        Withdrawal storage w = withdrawals[msg.sender][_id];
        uint256 val = w.val;

        require(current_era() - w.eraReq >= withdrawBlock, "Not enough eras passed!");
        require(unstakingPool >= val, "Unstaking pool drained!");

        w.eraReq = 0;

        distr.removeDnt(msg.sender, val, utilName, DNTname);
        payable(msg.sender).call{value: val};
    }

}