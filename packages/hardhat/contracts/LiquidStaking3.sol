//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/DappsStaking.sol";
import "./nDistributor.sol";

contract LiquidStaking is Initializable {
    DappsStaking public constant DAPPS_STAKING = DappsStaking(0x0000000000000000000000000000000000005001);    

    string public utilName;
    string public DNTname;
    uint256 minStake;

    uint256 unstakingPool;
    uint256 rewardPool;

    address public distrAddr;
    NDistributor   distr;

    mapping(uint256 => uint256) public eraStaked;
    mapping(uint256 => uint256) public eraUnstaked;
    mapping(uint256 => uint256) public eraStakerReward;
    mapping(uint256 => uint256) public eraDappReward;
    mapping(uint256 => uint256) public eraRevenue;

    function initialize() public initializer {

    }

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

    function global_stake(uint256 _era) external {
        DAPPS_STAKING.bond_and_stake(address(this), uint128(eraStaked[_era]));
    }

    function global_unstake(uint256 _era) external {
        DAPPS_STAKING.unbond_and_unstake(address(this), uint128(eraUnstaked[_era]));
    }

    function claim_dapp(uint256 _era) external {
        require(current_era() != _era, "Cannot claim yet!");
        require(eraDappReward[_era] == 0, "Already claimed!");
        uint256 p = address(this).balance;
        DAPPS_STAKING.claim_dapp(address(this), uint128(_era));
        uint256 a = address(this).balance;
        eraDappReward[_era] = a - p;
        eraRevenue[_era] += eraDappReward[_era] / 100 * 10; // 10% goes to unstaking pool
    }

    function claim_user(uint256 _era) external {
        uint256 p = address(this).balance;
        DAPPS_STAKING.claim_staker(address(this));
        uint256 a = address(this).balance;
        eraStakerReward[_era] = a - p;
        eraRevenue[_era] += eraStakerReward[_era] / 100; // 1% goes to unstaking pool
    }

    function stake() external payable {
        require(msg.value > minStake, "Send at least min stake value!");

        
        eraStaked[current_era()] += msg.value;
        distr.issueDnt(msg.sender, msg.value, utilName, DNTname);

    }

    function unstake(uint256 _amount, bool _immediate) external {
        require(_amount > 0, "Invalid amount!");
        eraUnstaked[current_era()] += _amount;
        if (_immediate) {
            uint256 fee = _amount / 100; // 1% immediate unstaking fee
            eraRevenue[current_era()] += fee;
            distr.removeDnt(msg.sender, _amount, utilName, DNTname);
            payable(msg.sender).call{value: _amount - fee};
        } else {
            // create withdrawal to pay later
        }
    }

    function claim() external {

    }

    function withdraw(uint256 _amount) external {
        // complete withdrawal
        distr.removeDnt(msg.sender, _amount, utilName, DNTname);
    }

}