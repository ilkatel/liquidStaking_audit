// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./interfaces/DappsStaking.sol";
import "./NDistributor.sol"; /* unused and will removed with next proxy update */
import "./interfaces/IPartnerHandler.sol"; /* 1 -> 1.5 will removed with next proxy update */
import "./interfaces/INFTDistributor.sol";
import "./interfaces/IAdaptersDistributor.sol";

abstract contract LiquidStakingStorage {
    DappsStaking public constant DAPPS_STAKING =
        DappsStaking(0x0000000000000000000000000000000000005001);
    bytes32 public constant MANAGER = keccak256("MANAGER");

    /// @notice settings for distributor
    string public utilName;
    string public DNTname;

    /// @notice core values
    uint public totalBalance;
    uint public withdrawBlock;

    /// @notice pool values
    uint public unstakingPool;
    uint public rewardPool;

    /// @notice distributor data
    NDistributor public distr;

    /* unused and will removed with next proxy update */struct Stake { 
    /* unused and will removed with next proxy update */    uint totalBalance;
    /* unused and will removed with next proxy update */    uint eraStarted;
    /* unused and will removed with next proxy update */}
    /* unused and will removed with next proxy update */mapping(address => Stake) public stakes;

    /// @notice user requested withdrawals
    struct Withdrawal {
        uint val;
        uint eraReq;
        uint lag;
    }
    mapping(address => Withdrawal[]) public withdrawals;

    /* unused and will removed with next proxy update */// @notice useful values per era
    /* unused and will removed with next proxy update */struct eraData {
    /* unused and will removed with next proxy update */    bool done;
    /* unused and will removed with next proxy update */    uint val;
    /* unused and will removed with next proxy update */}
    /* unused and will removed with next proxy update */mapping(uint => eraData) public eraUnstaked;
    /* unused and will removed with next proxy update */mapping(uint => eraData) public eraStakerReward; // total staker rewards per era
    /* unused and will removed with next proxy update */mapping(uint => eraData) public eraRevenue; // total revenue per era

    uint public unbondedPool;

    uint public lastUpdated; // last era updated everything

    // Reward handlers
    /* unused and will removed with next proxy update */address[] public stakers;
    /* unused and will removed with next proxy update */address public dntToken;
    mapping(address => bool) public isStaker;

    /* unused and will removed with next proxy update */uint public lastStaked;
    uint public lastUnstaked;

    /// @notice handlers for work with LP tokens
    /* unused and will removed with next proxy update */mapping(address => bool) public isLpToken;
    /* unused and will removed with next proxy update */address[] public lpTokens;

    /* unused and will removed with next proxy update */mapping(uint => uint) public eraRewards;

    uint public totalRevenue;

    /* unused and will removed with next proxy update */mapping(address => mapping(uint => uint)) public buffer;
    mapping(address => mapping(uint => uint[])) public usersShotsPerEra;  /* 1 -> 1.5 will removed with next proxy update */
    mapping(address => uint) public totalUserRewards;
    /* unused and will removed with next proxy update */mapping(address => address) public lpHandlers;

    uint public eraShotsLimit;  /* 1 -> 1.5 will removed with next proxy update */
    /* unused and will removed with next proxy update */uint public lastClaimed;
    uint public minStakeAmount;
    /* remove after migration */uint public sum2unstake;
    /* unused and will removed with next proxy update */bool public isUnstakes;
    /* unused and will removed with next proxy update */uint public claimingTxLimit;  // = 5;

    uint8 public constant REVENUE_FEE = 9; // 9% fee on MANAGEMENT_FEE
    uint8 public constant UNSTAKING_FEE = 1; // 1% fee on MANAGEMENT_FEE
    uint8 public constant MANAGEMENT_FEE = 10; // 10% fee on staking rewards

    // to partners will be added handlers and adapters. All handlers will be removed in future
    /* unused and will removed with next proxy update */mapping(address => bool) public isPartner;
    /* unused and will removed with next proxy update */mapping(address => uint) public partnerIdx;
    address[] public partners;  /* 1 -> 1.5 will removed with next proxy update */
    /* unused and will removed with next proxy update */uint public partnersLimit;  // = 15;

    struct Dapp {
        address dappAddress;
        uint256 stakedBalance;
        uint256 sum2unstake;
        mapping(address => Staker) stakers;
    }

    struct Staker {
        // era => era balance
        mapping(uint256 => uint256) eraBalance;
        // era => is zero balance
        mapping(uint256 => bool) isZeroBalance;

        uint256 rewards;
        uint256 lastClaimedEra;
    }
    uint256 public lastEraTotalBalance;
    uint256[2] public eraBuffer;

    string[] public dappsList;
    // util name => dapp
    mapping(string => Dapp) public dapps;
    mapping(string => bool) public haveUtility;
    mapping(string => bool) public isActive;
    mapping(string => uint256) public deactivationEra;
    mapping(uint256 => uint256) accumulatedRewardsPerShare;

    uint256 public constant REWARDS_PRECISION = 1e12;

    INFTDistributor public nftDistr;
    IAdaptersDistributor public adaptersDistr;

    address public liquidStakingManager;

    event Staked(address indexed user, uint val);
    event StakedInUtility(address indexed user, string indexed utility, uint val);
    event Unstaked(address indexed user, uint amount, bool immediate);
    event UnstakedFromUtility(address indexed user, string indexed utility, uint amount, bool immediate);
    event Withdrawn(address indexed user, uint val);
    event Claimed(address indexed user, uint amount);
    event ClaimedFromUtility(address indexed user, string indexed utility, uint amount);

    event HarvestRewards(address indexed user, string indexed utility, uint amount);

    // events for events handle
    event UnbondAndUnstakeError(string indexed utility, uint sum2unstake, uint indexed era, bytes indexed reason);
    event WithdrawUnbondedError(uint indexed _era, bytes indexed reason);
    event ClaimDappError(uint indexed amount, uint indexed era, bytes indexed reason);
    event SetMinStakeAmount(address indexed sender, uint amount);
    event WithdrawRevenue(uint amount);
    event Synchronization(address indexed sender, uint indexed era);
    event FillUnstaking(address indexed sender, uint value);
    event FillRewardPool(address indexed sender, uint value);
    event FillUnbonded(address indexed sender, uint value);
    event ClaimDappSuccess(uint eraStakerReward, uint indexed _era);
    event WithdrawUnbondedSuccess(uint indexed _era);
    event UnbondAndUnstakeSuccess(uint indexed era, uint sum2unstake);
    event ClaimStakerSuccess(uint indexed era, uint lastClaimed);
    event ClaimStakerError(string indexed utility, uint indexed era, bytes indexed reason);

    /// @notice get current era
    function currentEra() public view returns (uint) {
        return DAPPS_STAKING.read_current_era();
    }
}
