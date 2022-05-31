//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./interfaces/DappsStaking.sol";
import "./nDistributor.sol";
import "./Staker.sol";
import "../libs/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../libs/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../libs/@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../libs/@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @title Liquid staking contract
 */
contract LiquidStaking is Initializable, AccessControlUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    DappsStaking public constant DAPPS_STAKING = DappsStaking(0x0000000000000000000000000000000000005001);    


    // DECLARATIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKING SETTINGS
    // -------------------------------------------------------------------------------------------------------

    // @notice        core staking settings
    uint256   public    totalBalance;
    uint256   public    unstakingPool;
    uint256   public    minStake;

    // @notice DNT distributor
    address public distrAddr;
    NDistributor   distr;

    // @notice    nDistributor required values
    string public utilName; // Liquid Staking utility name
    string public DNTname; // DNT name

    // @notice Stake struct
    struct      Stake {
        uint256 eraStaked;
    }

    // @notice Stakes mapping to user
    mapping(address => Stake) public stakes;

    // @notice Withdrawal struct
    struct Withdrawal {
        uint256 val;
        uint256 eraReq;
    }
    // @notice Withdrawals array mapping to user
    mapping(address => Withdrawal[]) public withdrawals;

    // @notice eras until withdraw possible
    uint256   public    withdrawEras;
    address public stakerAddr;
    Staker staker;
    uint256 public rewardsPool;

    bytes32 public constant            STAKER = keccak256("STAKER");
    bytes32 public constant            ADMIN = keccak256("ADMIN");

    mapping(uint256 => uint256) public eraStaked;
    mapping(uint256 => uint256) public eraUnstaked;
    // FUNCTIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- INITIALIZER 
    // -------------------------------------------------------------------------------------------------------
    // @notice set distributor and DNT addresses, minimum staking amount
    // @param  [address] _distrAddr => DNT distributor address
    function initialize(address _distrAddr) public initializer {

        // @dev set distributor address and contract instance
        distrAddr = _distrAddr;
        distr = NDistributor(distrAddr);

        utilName = "LiquidStaking"; // Liquid Staking utility name
        DNTname  = "nASTR"; // DNT name

        stakerAddr = "/* put deployed staker contract address here */";
        staker = Staker(stakerAddr);

        minStake = 5 ether;
        withdrawEras = 10;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN, msg.sender);
        _grantRole(STAKER, stakerAddr);
    }

    function fillRewardsPool() external payable onlyRole(STAKER) { // rewards goes here
        require(msg.value > 0, "0 value!");
        rewardsPool += msg.value;
    }

    function fillUnstakingPool() external payable onlyRole(STAKER) { // 10% revenue from staker goes here
        require(msg.value > 0, "0 value!");
        unstakingPool += msg.value;
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- ADMIN
    // -------------------------------------------------------------------------------------------------------

    // @notice set distributor
    // @param  [address] a => new distributor address
    function   setDistr(address a) external onlyRole(ADMIN) {
        distrAddr = a;
        distr = NDistributor(distrAddr);
    }

    // @notice set minimum stake value
    // @param  [uint256] v => new minimum stake value
    function   setMinStake(uint256 v) external onlyRole(ADMIN) {
        minStake = v;
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- VIEWS
    // -------------------------------------------------------------------------------------------------------

    // @notice returns current era number from DAPPS_STAKING module
    function   current_era() public view returns(uint256) {
        return DAPPS_STAKING.read_current_era();
    }

    // @notice returns apr in %
    function   get_apr() public view returns(uint256) {
        uint32 era = uint32(DAPPS_STAKING.read_current_era() - 1);
        return (DAPPS_STAKING.read_era_staked(era) / DAPPS_STAKING.read_era_reward(era) / 100); // divide total staked by total rewards for prev era
    }

    // @notice returns user active withdrawals
    function get_user_withdrawals() public view returns(Withdrawal[] memory) {
        return withdrawals[msg.sender];
    }

    function calculate_reward() public view returns (uint256) {
        uint256 uBalance = distr.getUserDntBalanceInUtil(msg.sender, utilName, DNTname);
        uint256 part = totalBalance / uBalance / 100; // % of total
        return rewardsPool / 100 * part; // so user can get equal part of rewards pool

    }

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKE
    // -------------------------------------------------------------------------------------------------------

    // @notice create new stake with desired timeframe
    function   stake() external payable {
        uint256 val = msg.value;
		require(val >= minStake, "Value less than minimum stake amount");

        Stake storage s = stakes[msg.sender];
        uint256 era = current_era();

        s.eraStaked = s.eraStaked == 0 ? era : s.eraStaked;

        totalBalance += val;
        eraStaked[era] += val;

        distr.issueDnt(msg.sender, val, utilName, DNTname);

        // send funds to staker
        payable(stakerAddr).call{value: msg.value};
    }

    // @notice unstake DNTs to retrieve native tokens from stake
    // @param  [uint256] amount => amount of tokens to unstake
    // @param  [bool] immediate => false if call unbond, 'true' not yet implemented
    function   unstake(uint256 amount, bool immediate) external {
        require(amount > 0, "Invalid amount!");

        uint256 uBalance = distr.getUserDntBalanceInUtil(msg.sender, utilName, DNTname);
        require(uBalance >= amount, "Insuffisient DNT balance!");
        totalBalance -= amount;
        eraUnstaked[current_era()] += amount;

        if (immediate) {
            unstakingPool -= amount;
            uint256 coms = amount / 100; // 1% immedieate coms
            payable(msg.sender).call{value: amount - coms};
        }else {
            withdrawals[msg.sender].push(Withdrawal({
                val: amount,
                eraReq: current_era()
            }));
        }
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- CLAIM
    // -------------------------------------------------------------------------------------------------------

    // @notice claim user rewards
    function claim_user() external {
        uint256 reward = calculate_reward();
        require(rewardsPool >= reward, "Rewards pool has less liquidity!");
        rewardsPool -= reward;
        payable(msg.sender).call{value: reward};

    }
    

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- WITHDRAW
    // -------------------------------------------------------------------------------------------------------
    
    // @notice withdraw unbonded
    function withdraw(uint id) external {
        Withdrawal storage w = withdrawals[msg.sender][id]; 
        require(current_era() - w.eraReq > withdrawEras, "Not enough eras passed!");
        unstakingPool -= w.val;
        w.eraReq = 0;
        distr.removeDnt(msg.sender, w.val, utilName, DNTname);
        payable(msg.sender).call{value: w.val};
    }
}
