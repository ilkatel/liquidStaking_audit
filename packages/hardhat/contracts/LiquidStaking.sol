//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../libs/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/DappsStaking.sol";
import "./nDistributor.sol";

//shibuya: 0xD9E81aDADAd5f0a0B59b1a70e0b0118B85E2E2d3
contract LiquidStaking is Initializable, AccessControlUpgradeable {
    DappsStaking public constant DAPPS_STAKING = DappsStaking(0x0000000000000000000000000000000000005001);    
    bytes32 public constant            MANAGER = keccak256("MANAGER");

    string public utilName; // LiquidStaking
    string public DNTname; // nASTR

    uint256 public totalBalance;
    uint256 public minStake;
    uint256 public withdrawBlock;

    uint256 public unstakingPool;
    uint256 public rewardPool;

    address public distrAddr;
    NDistributor   distr;

    mapping(address => mapping(uint256 => bool)) public userClaimed;

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
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
    }

    function setup() external onlyRole(MANAGER) {
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();
        DNTname = "nASTR";
        utilName = "LiquidStaking";
        DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance);
    }


    // ADMIN FUNCS
    function set_distr(address _newDistr) public onlyRole(MANAGER) {
        distrAddr = _newDistr;
        distr = NDistributor(distrAddr);
    }

    function set_min(uint256 _val) public onlyRole(MANAGER) {
        minStake = _val;
    }


    // VIEWS

    function current_era() public view returns(uint256) {
        return DAPPS_STAKING.read_current_era();
    }

    function user_reward(uint256 _era) public view returns (uint256) {
        uint256 share = totalBalance / stakes[msg.sender].totalBalance / 100; // user share in %
        return eraStakerReward[_era].val / 100 * share;
    }

    // GLOBAL FUNCS
    // @dev stake for given era
    function global_stake(uint256 _era) external {
        eraData storage d = eraStaked[_era];

        require(!d.done, "Already done!");

        d.done = true;

        DAPPS_STAKING.bond_and_stake(address(this), uint128(d.val));
    }

    // @dev unstake for given era
    function global_unstake(uint256 _era) external {
        eraData storage d = eraUnstaked[_era];

        require(!d.done, "Already done!");

        d.done = true;

        DAPPS_STAKING.unbond_and_unstake(address(this), uint128(d.val));
    }

    // @dev withdraw
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

        uint256 coms = (a - p) / 10; // 10% goes to revenue pool

        eraDappReward[_era].val = a - p - coms;
        eraRevenue[_era].val += coms;
    }

    function claim_user(uint256 _era) external {
        uint256 p = address(this).balance;
        DAPPS_STAKING.claim_staker(address(this));
        uint256 a = address(this).balance;

        uint256 coms = (a - p) / 100; // 1% comission to revenue pool

        eraStakerReward[_era].val = a - p - coms;
        eraRevenue[_era].val += coms;
    }

    function fill_pools(uint256 _era) external {
        require(!eraRevenue[_era].done, "Already done!");
        require(!eraStakerReward[_era].done, "Already done!");

        eraRevenue[_era].done = true;
        eraStakerReward[_era].done = true;

        unstakingPool += eraRevenue[_era].val / 10; // 10% of revenue goes to unstaking pool
        rewardPool += eraStakerReward[_era].val;
    }


    // USER FUNCS
    function stake() external payable {
        Stake storage s = stakes[msg.sender];
        uint256 era = current_era();
        uint256 val = msg.value;

        require(val >= minStake, "Send at least min stake value!");

        totalBalance += val;
        eraStaked[era].val += val;

        s.totalBalance += val;
        s.eraStarted = s.eraStarted == 0 ? era : s.eraStarted;

        distr.issueDnt(msg.sender, val, utilName, DNTname);
    }

    function unstake(uint256 _amount, bool _immediate) external {
        Stake storage s = stakes[msg.sender];
        uint256 era = current_era();
        require(_amount > 0, "Invalid amount!");
        require(s.totalBalance >= _amount, "Invalid amount!");

        eraUnstaked[era].val += _amount;

        totalBalance -= _amount;
        s.totalBalance -= _amount;
        if(s.totalBalance == 0) {
            s.eraStarted = 0;
        }

        if (_immediate) {
            require(unstakingPool >= _amount, "Unstaking pool drained!");
            uint256 fee = _amount / 100; // 1% immediate unstaking fee
            eraRevenue[era].val += fee;
            unstakingPool -= _amount;
            distr.removeDnt(msg.sender, _amount, utilName, DNTname);
            payable(msg.sender).call{value: _amount - fee};
        } else {
            withdrawals[msg.sender].push(Withdrawal({
                val: _amount,
                eraReq: era
            }));
        }
    }

    function claim(uint256 _era) external {
        require(!userClaimed[msg.sender][_era], "Already claimed!");
        userClaimed[msg.sender][_era] = true;
        uint256 reward = user_reward(_era);
        require(rewardPool >= reward, "Rewards pool drained!");
        rewardPool -= reward;
        payable(msg.sender).call{value: reward};
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