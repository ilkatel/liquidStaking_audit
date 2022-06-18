//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../libs/@openzeppelin/contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "./interfaces/DappsStaking.sol";
import "./nDistributor.sol";
import "./interfaces/IDNT.sol";

interface ILpToken {
    function balanceOf(address) external view returns (uint256);
}

//shibuya: 0xD9E81aDADAd5f0a0B59b1a70e0b0118B85E2E2d3
contract LiquidStaking is Initializable, AccessControlUpgradeable {
    DappsStaking public constant DAPPS_STAKING =
        DappsStaking(0x0000000000000000000000000000000000005001);
    bytes32 public constant MANAGER = keccak256("MANAGER");

    // @notice settings for distributor
    string public utilName;
    string public DNTname;

    // @notice core values
    uint256 public totalBalance;
    uint256 public minStake; // remove when next proxy deployed
    uint256 public withdrawBlock;

    // @notice
    uint256 public unstakingPool;
    uint256 public rewardPool;

    // @notice distributor data
    address public distrAddr;
    NDistributor distr;

    mapping(address => mapping(uint256 => bool)) public userClaimed; // remove when next proxy deployed

    // @notice core stake struct and stakes per user, remove with next proxy update. All done via distr
    struct Stake {
        uint256 totalBalance;
        uint256 eraStarted;
    }
    mapping(address => Stake) public stakes;

    // @notice user requested withdrawals
    struct Withdrawal {
        uint256 val;
        uint256 eraReq;
    }
    mapping(address => Withdrawal[]) public withdrawals;

    // @notice useful values per era
    struct eraData {
        bool done;
        uint256 val;
    }
    mapping(uint256 => eraData) public eraStaked; // total tokens staked per era
    mapping(uint256 => eraData) public eraUnstaked; // total tokens unstaked per era
    mapping(uint256 => eraData) public eraStakerReward; // total staker rewards per era
    mapping(uint256 => eraData) public eraDappReward; // total dapp rewards per era
    mapping(uint256 => eraData) public eraRevenue; // total revenue per era

    uint256 public unbondedPool;

    address public proxyAddr;

    uint256 public lastUpdated; // last era updated everything

    // Reward handlers
    mapping(address => uint256) public rewardsByAddress;
    address[] public stakers;
    address public dntToken;
    mapping(address => bool) public isStaker;

    uint256 public lastStaked;
    uint256 public lastUnstaked;

    mapping(address => uint256) private shadowTokensAmount; // <-- not used

    // @notice                         handlers for work with LP tokens
    //                                 for now supposed rate 1 dnt / 1 lpToken
    mapping(address => bool) public isLpToken;
    mapping(address => bool) public hasLpTokens;
    address[] public lpTokens;
    uint256 public lastRewardsCalculated;

    mapping(address => mapping(uint256 => bool)) public userCalcd; // remove when next proxy deployed
    mapping(address => uint256) lastUserCalcd; // last era user reward calculated

    mapping(uint => uint) public eraToSnapshot;
    mapping(address => uint) public stakersFirstEra;
    mapping(address => uint) public mulForLpToken;
    mapping(address => uint) public divForLpToken;

    // ------------------ INIT
    // -----------------------
    function initialize() public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        proxyAddr = msg.sender;
        lastUpdated = DAPPS_STAKING.read_current_era() - 1;
        lastStaked = 1175;
        lastUnstaked = 1178;
    }

    // @notice set init values
    function setup() external onlyRole(MANAGER) {
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();
        DNTname = "nSBY";
        utilName = "LiquidStaking";
    }

    // ------------------ ADMIN
    // ------------------------

    // @notice set distributor address
    function setDistr(address _newDistr) public onlyRole(MANAGER) {
        distrAddr = _newDistr;
        distr = NDistributor(distrAddr);
    }

    // @notice set DNT address
    function setDntToken(address _address) public onlyRole(MANAGER) {
        dntToken = _address;
    }

    // @dev debug purposes
    function setProxy(address _p) public onlyRole(MANAGER) {
        proxyAddr = _p;
    }

    // @dev debug purposes
    function setLast(uint256 _val) public onlyRole(MANAGER) {
        lastUpdated = _val;
    }

    // @dev debug purposes
    function setLastS(uint256 _val) public onlyRole(MANAGER) {
        lastStaked = _val;
    }

    // @dev debug purposes
    function setLastU(uint256 _val) public onlyRole(MANAGER) {
        lastUnstaked = _val;
    }

    // @dev for correct rewards calculation
    function addLpToken(address _lp) public onlyRole(MANAGER) {
        isLpToken[_lp] = true;
        lpTokens.push(_lp);
    }

    function addToLpOwners(address _user) public {
        hasLpTokens[_user] = true;
    }

    function setLRC(uint256 _val) public onlyRole(MANAGER) {
        lastRewardsCalculated = _val;
    }

    // ------------------ VIEWS
    // ------------------------
    // @notice get current era
    function currentEra() public view returns (uint256) {
        return DAPPS_STAKING.read_current_era();
    }

    // @notice return stakers array
    function getStakers() public view returns (address[] memory) {
        require(
            msg.sender == dntToken && msg.sender != address(0),
            "> Only available for token contract!"
        );
        return stakers;
    }

    // @notice returns user active withdrawals
    function getUserWithdrawals() public view returns (Withdrawal[] memory) {
        return withdrawals[msg.sender];
    }

    function chck() public calcReward {

    }

    function getUserLpTokens(address _user) public view returns (uint amount) {
        address[] memory _lpTokens = lpTokens;
        uint mul = mulForLpToken[_user] > 0 ? mulForLpToken[_user] : 1;
        uint div = divForLpToken[_user] > 0 ? divForLpToken[_user] : 1;
        for (uint i; i < _lpTokens.length;) {
            amount += ILpToken(_lpTokens[i]).balanceOf(_user)*mul/div;
            unchecked { ++i; }
        }
    }

    // function user_reward(address _staker, uint256 _era)
    //     public
    //     view
    //     returns (uint256 reward)
    // {
    //     uint256 lpBalance; // amount of user lp tokens
    //
    //     if (lastRewardsCalculated == _era) {
    //         reward = rewardsByAddress[_staker];
    //     } else {
    //         if (!isLpToken[_staker]) {
    //             lpBalance += getUserLpTokens(_staker);
    //         }
    //
    //         uint256 stakerDntBalance = distr.getUserDntBalanceInUtil(
    //             _staker,
    //             utilName,
    //             DNTname
    //         );
    //         return
    //             rewardsByAddress[_staker] +
    //             (eraStakerReward[_era].val * (stakerDntBalance + lpBalance)) /
    //             totalBalance;
    //     }
    // }

    // @notice must calls in due era changing
    //         does snapshot and write its id to mapping
    function eraShot() public onlyRole(MANAGER) {
        uint256 snapshotId = IDNT(dntToken).snapshot();
        uint256 era = currentEra();
        eraToSnapshot[era] = snapshotId;
    }

    function setFirstEra(address _staker, uint _era) public onlyDistributor() {
        stakersFirstEra[_staker] = _era;
    }

    function getUserRewards(address _user) public view returns (uint amount) {
        uint era = currentEra();
        uint firstEra = stakersFirstEra[_user];
        uint totalDntBalance = IDNT(dntToken).totalSupply();
        require(era >= firstEra + 2, "Staker havent rewards yet!");

        for (uint _era = firstEra+1; _era < era;) {

            uint snapshotId = eraToSnapshot[_era];
            uint totalEraRewards = DAPPS_STAKING.read_era_reward(uint32(_era));
            uint dntBalance = IDNT(dntToken).balanceOfAt(_user, snapshotId);
            uint lpBalance = getUserLpTokens(_user);

            amount += (totalEraRewards * (dntBalance + lpBalance)) /
            totalDntBalance;

            unchecked { ++_era; }
        }
    }

    function setMulForLpToken(address _lpToken, uint _val) public onlyRole(MANAGER) {
        mulForLpToken[_lpToken] = _val;
    }

    function setDivForLpToken(address _lpToken, uint _val) public onlyRole(MANAGER) {
        divForLpToken[_lpToken] = _val;
    }

    // ------------------ DAPPS_STAKING
    // --------------------------------

    // @notice stake tokens from not yet updated eras
    // @param  [uint256] _era => latest era to update
    function globalStake(uint256 _era) public {
        uint128 sum2stake = 0;

        for (uint256 i = lastStaked + 1; i <= _era; ) {
            sum2stake += uint128(eraStaked[i].val);
            eraStaked[i].done = true;
            unchecked {
                ++i;
            }
        }

        if (sum2stake > 0) {
            DAPPS_STAKING.bond_and_stake(proxyAddr, sum2stake);
            lastStaked = _era;
        }
    }

    // @notice ustake tokens from not yet updated eras
    // @param  [uint256] _era => latest era to update
    function globalUnstake(uint256 _era) public {
        uint128 sum2unstake = 0;

        for (uint256 i = lastUnstaked + 1; i <= _era; ) {
            eraUnstaked[i].done = true;
            sum2unstake += uint128(eraUnstaked[i].val);
            unchecked {
                ++i;
            }
        }

        if (sum2unstake > 0) {
            DAPPS_STAKING.unbond_and_unstake(proxyAddr, sum2unstake);
            lastUnstaked = _era;
        }
    }

    // @notice withdraw unbonded tokens
    // @param  [uint256] _era => desired era
    function globalWithdraw(uint256 _era) public {
        for (uint256 i = lastUpdated + 1; i <= _era; ) {
            if (eraUnstaked[i - withdrawBlock].val != 0) {
                uint256 p = address(proxyAddr).balance;
                DAPPS_STAKING.withdraw_unbonded();
                uint256 a = address(proxyAddr).balance;
                unbondedPool += a - p;

                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    // @notice LS contract claims staker rewards
    function globalClaim(uint256 _era) public {
        // claim rewards
        uint256 p = address(proxyAddr).balance;
        DAPPS_STAKING.claim_staker(proxyAddr);
        uint256 a = address(proxyAddr).balance;

        uint256 coms = (a - p) / 100; // 1% comission to revenue pool

        eraStakerReward[_era].val = a - p - coms; // rewards to share between users
        eraRevenue[_era].val += coms;
    }

    // @notice claim dapp rewards, transferred to dapp owner
    // @param  [uint256] _era => desired era number
    function claimDapp(uint256 _era) public {
        /*
        require(currentEra() != _era, "Cannot claim yet!");
        require(eraDappReward[_era].val == 0, "Already claimed!");
        uint256 p = address(proxyAddr).balance;
        */
        DAPPS_STAKING.claim_dapp(proxyAddr, uint128(_era));
        /*
        uint256 a = address(proxyAddr).balance;
        uint256 coms = (a - p) / 10; // 10% goes to revenue pool
        eraDappReward[_era].val = a - p - coms;
        eraRevenue[_era].val += coms;
        */
    }

    // -------------- USER FUNCS
    // -------------------------

    // @notice updates global balances, stakes/unstakes etc
    modifier updateAll() {
        uint256 era = currentEra() - 1; // last era to update
        if (lastUpdated != era) {
            globalWithdraw(era);
            claimDapp(era);
            globalClaim(era);
            globalStake(era);
            globalUnstake(era);
            fillPools(era);
            lastUpdated = era;
        }
        _;
    }

    modifier calcReward() {
        // uint256 era = currentEra() - 1;
        // address stakerAddr = msg.sender;
        //
        // if (lastUserCalcd[stakerAddr] < era) {
        //     rewardsByAddress[stakerAddr] = user_reward(stakerAddr, era);
        //     lastUserCalcd[stakerAddr] = era;
        // }
        _;
    }

    modifier onlyDistributor() {
        require(msg.sender == distrAddr, "Only for distributor!");
        _;
    }

    // @notice stake native tokens, receive equal amount of DNT
    function stake() external payable updateAll calcReward {
        Stake storage s = stakes[msg.sender];
        uint256 era = currentEra();
        uint256 val = msg.value;

        totalBalance += val;
        eraStaked[era].val += val;

        s.totalBalance += val;
        s.eraStarted = s.eraStarted == 0 ? era : s.eraStarted;

        if (!isStaker[msg.sender]) {
            isStaker[msg.sender] = true;
            stakers.push(msg.sender);
            stakersFirstEra[msg.sender] = era;
        }

        distr.issueDnt(msg.sender, val, utilName, DNTname);
    }

    // @notice unstake tokens from app, loose DNT
    // @param  [uint256] _amount => amount of tokens to unstake
    // @param  [bool] _immediate => receive tokens from unstaking pool, create a withdrawal otherwise
    function unstake(uint256 _amount, bool _immediate) external updateAll calcReward {
        uint256 userDntBalance = distr.getUserDntBalanceInUtil(
            msg.sender,
            utilName,
            DNTname
        );
        Stake storage s = stakes[msg.sender];

        require(userDntBalance >= _amount, "> Not enough nASTR!");
        require(_amount > 0, "Invalid amount!");

        uint256 era = currentEra();
        eraUnstaked[era].val += _amount;

        totalBalance -= _amount;
        // check current stake balance of user
        // set it zero if not enough
        // reduce else
        if (s.totalBalance >= _amount) {
            s.totalBalance -= _amount;
        } else {
            s.totalBalance = 0;
            s.eraStarted = 0;
        }
        distr.removeDnt(msg.sender, _amount, utilName, DNTname);

        if (_immediate) {
            // get liquidity from unstaking pool
            require(unstakingPool >= _amount, "Unstaking pool drained!");
            uint256 fee = _amount / 100; // 1% immediate unstaking fee
            eraRevenue[era].val += fee;
            unstakingPool -= _amount;
            payable(msg.sender).transfer(_amount - fee);
        } else {
            // create a withdrawal to withdraw_unbonded later
            withdrawals[msg.sender].push(
                Withdrawal({val: _amount, eraReq: era})
            );
        }
    }

    // @notice claim rewards by user
    // @param  [uint256] _amount => amount of claimed reward
    function claim(uint256 _amount) external updateAll calcReward {
        require(rewardPool >= _amount, "Rewards pool drained!");
        require(
            getUserRewards(msg.sender) >= _amount,
            "> Not enough rewards!"
        );

        rewardPool -= _amount;
        // rewardsByAddress[msg.sender] -= _amount;

        payable(msg.sender).transfer(_amount);
    }

    // @notice finish previously opened withdrawal
    // @param  [uint256] _id => withdrawal index
    function withdraw(uint256 _id) external updateAll calcReward {
        Withdrawal storage w = withdrawals[msg.sender][_id];
        uint256 val = w.val;
        uint256 era = currentEra();

        require(era - w.eraReq >= withdrawBlock, "Not enough eras passed!");
        require(unbondedPool >= val, "Unbonded pool drained!");

        unbondedPool -= val;
        w.eraReq = 0;

        payable(msg.sender).transfer(val);
    }

    // ------------------ MISC
    // -----------------------

    // @notice add new staker and save balances
    // @param  [address] => user to add
    function addStaker(address _addr) public {
        uint256 stakerDntBalance = distr.getUserDntBalanceInUtil(
            _addr,
            utilName,
            DNTname
        );
        stakes[msg.sender].totalBalance = stakerDntBalance;
        rewardsByAddress[_addr] = 0;
        stakers.push(_addr);
        isStaker[_addr] = true;
    }

    // @notice fill pools with reward comissions etc
    // @param  [uint256] _era => desired era
    function fillPools(uint256 _era) public {
        // iterate over non-processed eras
        for (uint256 i = lastUpdated + 1; i <= _era; ) {
            eraRevenue[i].done = true;
            unstakingPool += eraRevenue[i].val / 10; // 10% of revenue goes to unstaking pool
            unchecked {
                ++i;
            }
        }

        eraStakerReward[_era].done = true;
        rewardPool += eraStakerReward[_era].val;
    }

    // @notice manually fill the unbonded pool
    function fillUnbonded() external payable {
        require(msg.value > 0, "Provide some value!");
        unbondedPool += msg.value;
    }

    // @notice manually fill the unstaking pool
    function fillUnstaking() external payable {
        require(msg.value > 0, "Provide some value!");
        unstakingPool += msg.value;
    }
}
