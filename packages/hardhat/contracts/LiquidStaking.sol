//SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "../libs/@openzeppelin/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../libs/@openzeppelin/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "../libs/@openzeppelin/openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "./interfaces/DappsStaking.sol";
import "./nDistributor.sol";
import "./interfaces/IDNT.sol";

interface ILpHandler {
    function calc(address) external view returns (uint);
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
    uint256 public withdrawBlock;

    // @notice
    uint256 public unstakingPool;
    uint256 public rewardPool;

    // @notice distributor data
    NDistributor public distr;

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
    mapping(uint256 => eraData) public eraRevenue; // total revenue per era

    uint256 public unbondedPool;

    uint256 public lastUpdated; // last era updated everything

    // Reward handlers
    address[] public stakers;
    address public dntToken;
    mapping(address => bool) public isStaker;

    uint256 public lastStaked;
    uint256 public lastUnstaked;

    // @notice handlers for work with LP tokens
    //         for now supposed rate 1 dnt / 1 lpToken
    mapping(address => bool) public isLpToken;
    address[] public lpTokens;

    mapping(uint => uint) public eraRewards;

    uint public totalRevenue;

    mapping(address => mapping(uint => uint)) public buffer;
    mapping(address => mapping(uint => uint[])) public userIncompleteEraRewards;
    mapping(address => uint) public totalUserRewards;
    mapping(address => address) public lpHandlers;

    event Staked(address user, uint val);
    event Unstaked(address user, uint amount, bool immediate);
    event Withdrawn(address user, uint val);
    event Claimed(address user, uint amount);

    using AddressUpgradeable for address payable;

    // ------------------ INIT
    // -----------------------
    function initialize(
        string memory _DNTname,
        string memory _utilName,
        address _distrAddr,
        address _dntToken
    ) public initializer {
        uint era = DAPPS_STAKING.read_current_era() - 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();
        DNTname = _DNTname;
        utilName = _utilName;
        distr = NDistributor(_distrAddr);
        dntToken = _dntToken;

        lastUpdated = era;
        lastStaked = era;
        lastUnstaked = era;
    }

    // ------------------ VIEWS
    // ------------------------
    // @notice get current era
    function currentEra() public view returns (uint256) {
        return DAPPS_STAKING.read_current_era();
    }

    // @notice return stakers array
    function getStakers() external view returns (address[] memory) {
        return stakers;
    }

    // @notice returns user active withdrawals
    function getUserWithdrawals() external view returns (Withdrawal[] memory) {
        return withdrawals[msg.sender];
    }

    // @notice add lp token address
    function addLpToken(address _lp) external onlyRole(MANAGER) {
        require(!isLpToken[_lp], "Allready added");
        isLpToken[_lp] = true;
        lpTokens.push(_lp);
    }

    // @notice add contract address to calculate LP amount for each user
    function addLpHandler(address _lp, address _handler) external onlyRole(MANAGER) {
        lpHandlers[_lp] = _handler;
    }

    // @notice iterate by each lp token address and get user rewards from handlers
    function getUserLpTokens(address _user) public view returns (uint) {
        uint amount;
        address[] memory _lpTokens = lpTokens;
        if (_lpTokens.length == 0) {
            return 0;
        }
        for (uint i; i < _lpTokens.length;) {
            amount += ILpHandler(lpHandlers[_lpTokens[i]]).calc(_user);
            unchecked { ++i; }
        }
        return amount;
    }

    function getLpTokens() public view returns (address[] memory) {
        return lpTokens;
    }

    // @notice removing lp token address from list
    function removeLpToken(address _lp) external onlyRole(MANAGER) {
        require(isLpToken[_lp], "This LP token is not in the list");
        isLpToken[_lp] = false;
        for (uint i; i < lpTokens.length; i++) {
            if (lpTokens[i] == _lp) {
                lpTokens[i] = lpTokens[lpTokens.length - 1];
                lpTokens.pop();
            }
        }
    }

    // @notice sorts the list in ascending order and return mean
    function findMean(uint[] memory _arr) private pure returns (uint mean) {
        uint uMax = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        uint[] memory arr = _arr;
        uint[] memory sorted = new uint[](arr.length);
        uint len = arr.length;

        for (uint i; i < len; i++) {
            uint min = type(uint).max - 1;

            for (uint j; j < len; j++) {
                if (arr[j] < min) {
                    min = arr[j];
                }
            }
            for (uint k; k < len; k++) {
                if (arr[k] == min) {
                    arr[k] = uMax;
                    break;
                }
            }
            sorted[i] = min;
        }

        mean = sorted[len/2];
    }

    // @notice add amount to buffer until next era
    function addToBuffer(address _user, uint _amount) external onlyDistributor() {
        uint era = currentEra();
        buffer[_user][era] += _amount;
    }

    // @notice saving information about users balances
    function eraShot(address _user, string memory _util, string memory _dnt) external onlyRole(MANAGER) {
        uint era = currentEra();

        // check if it is first shot in current era
        if (userIncompleteEraRewards[_user][era].length == 0) {
            uint prevEraRewards = DAPPS_STAKING.read_era_reward(uint32(era - 1));
            uint[] memory arr = userIncompleteEraRewards[_user][era - 1];
            uint userLastEraRewards = findMean(arr) * prevEraRewards / 10**18;
            totalUserRewards[_user] += userLastEraRewards;
        }

        uint nBal = distr.getUserDntBalance(_user, _dnt);
        uint lpBal = getUserLpTokens(_user);
        uint nTotal = distr.getUserDntBalanceInUtil(_user, _util, _dnt);
        uint algemEraStaked = DAPPS_STAKING.read_staked_amount_on_contract(address(this), abi.encodePacked(address(this)));
        uint totalEraStaked = DAPPS_STAKING.read_era_staked(uint32(era));

        uint nShare = (nBal + lpBal - buffer[_user][era]) / nTotal;
        uint stakedShare = (algemEraStaked / totalEraStaked) * 10**18;
        uint incompleteData = nShare * stakedShare;

        // array with data without totalEraRewards,
        // which will be added at the start of the next era
        userIncompleteEraRewards[_user][era].push(incompleteData);
    }

    // @notice return users rewards
    function getUserRewards(address _user) public view returns (uint) {
        return totalUserRewards[_user];
    }

    // ------------------ DAPPS_STAKING
    // --------------------------------

    // @notice stake tokens from not yet updated eras
    // @param  [uint256] _era => latest era to update
    function globalStake(uint256 _era) private {
        uint128 sum2stake = 0;

        for (uint256 i = lastStaked + 1; i <= _era; ) {
            sum2stake += uint128(eraStaked[i].val);
            eraStaked[i].done = true;
            unchecked {
                ++i;
            }
        }

        if (sum2stake > 0) {
            try DAPPS_STAKING.bond_and_stake(address(this), sum2stake) {} catch {}
        }
        lastStaked = _era;
    }

    // @notice ustake tokens from not yet updated eras
    // @param  [uint256] _era => latest era to update
    function globalUnstake(uint256 _era) private {
        uint128 sum2unstake = 0;

        for (uint256 i = lastUnstaked + 1; i <= _era; ) {
            eraUnstaked[i].done = true;
            sum2unstake += uint128(eraUnstaked[i].val);
            unchecked {
                ++i;
            }
        }

        if (sum2unstake > 0) {
            try DAPPS_STAKING.unbond_and_unstake(address(this), sum2unstake) {} catch {}
        }
        lastUnstaked = _era;
    }

    // @notice withdraw unbonded tokens
    // @param  [uint256] _era => desired era
    function globalWithdraw(uint256 _era) private {
        bool isUnstaked;

        // checks if there is unstaked eras
        for (uint256 i = lastUpdated + 1; i <= _era; ) {
            if (eraUnstaked[i - withdrawBlock].val != 0) {
                isUnstaked = true;
                break;
            }
            unchecked { ++i; }
        }

        uint256 p = address(this).balance;

        // if there is unstaked eras, withdraw unbonded
        // and reset all eraUnstaked
        if (isUnstaked) {
            try DAPPS_STAKING.withdraw_unbonded() {
                for (uint256 i = lastUpdated + 1; i <= _era; ) {
                    if (eraUnstaked[i - withdrawBlock].val != 0) {
                        eraUnstaked[i - withdrawBlock].val = 0;
                    }
                    unchecked { ++i; }
                }
            } catch {}
        }
        uint256 a = address(this).balance;
        unbondedPool += a - p;
    }

    // @notice LS contract claims staker rewards
    function globalClaim(uint256 _era) private {
        // claim rewards
        require(_era < currentEra(), "This era has not yet come");
        uint256 p = address(this).balance;
        DAPPS_STAKING.claim_staker(address(this));
        uint256 a = address(this).balance;

        uint256 coms = (a - p) / 100; // 1% comission to revenue pool

        eraStakerReward[_era].val += a - p - coms; // rewards to share between users
        eraRevenue[_era].val += coms;
        totalRevenue += coms;
    }

    // @notice claim dapp rewards, transferred to dapp owner
    // @param  [uint256] _era => desired era number
    function claimDapp(uint256 _era) private {
        for (uint256 i = lastUpdated + 1; i <= _era; ) {
            try DAPPS_STAKING.claim_dapp(address(this), uint128(_era)) {} catch {}
            unchecked { ++i; }
        }
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

    modifier onlyDistributor() {
        require(msg.sender == address(distr), "Only for distributor!");
        _;
    }

    // @notice stake native tokens, receive equal amount of DNT
    function stake() external payable updateAll {
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
        }

        distr.issueDnt(msg.sender, val, utilName, DNTname);
        emit Staked(msg.sender, val);
    }

    // @notice unstake tokens from app, loose DNT
    // @param  [uint256] _amount => amount of tokens to unstake
    // @param  [bool] _immediate => receive tokens from unstaking pool, create a withdrawal otherwise
    function unstake(uint256 _amount, bool _immediate) external updateAll {
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
            totalRevenue += fee;
            unstakingPool -= _amount;
            payable(msg.sender).sendValue(_amount - fee);
        } else {
            // create a withdrawal to withdraw_unbonded later
            withdrawals[msg.sender].push(
                Withdrawal({val: _amount, eraReq: era})
            );
        }
        emit Unstaked(msg.sender, _amount, _immediate);
    }

    // @notice claim rewards by user
    // @param  [uint256] _amount => amount of claimed reward
    function claim(uint256 _amount) external updateAll {
        require(rewardPool >= _amount, "Rewards pool drained!");
        require(
            totalUserRewards[msg.sender] >= _amount,
            "> Not enough rewards!"
        );
        rewardPool -= _amount;
        totalUserRewards[msg.sender] -= _amount;
        payable(msg.sender).sendValue(_amount);

        emit Claimed(msg.sender, _amount);
    }

    // @notice finish previously opened withdrawal
    // @param  [uint256] _id => withdrawal index
    function withdraw(uint256 _id) external updateAll {
        Withdrawal storage withdrawal = withdrawals[msg.sender][_id];
        uint256 val = withdrawal.val;
        uint256 era = currentEra();

        require(withdrawal.eraReq != 0, "Withdrawal already claimed");
        require(era - withdrawal.eraReq >= withdrawBlock, "Not enough eras passed!");
        require(unbondedPool >= val, "Unbonded pool drained!");

        unbondedPool -= val;
        withdrawal.eraReq = 0;

        payable(msg.sender).sendValue(val);
        emit Withdrawn(msg.sender, val);
    }

    // ------------------ MISC
    // -----------------------

    // @notice add new staker and save balances
    // @param  [address] => user to add
    function addStaker(address _addr, string memory _util, string memory _dnt) external onlyDistributor() {
        require(!isStaker[_addr], "Already staker");
        uint256 stakerDntBalance = distr.getUserDntBalanceInUtil(_addr, _util, _dnt);
        stakes[_addr].totalBalance = stakerDntBalance;
        stakers.push(_addr);
        isStaker[_addr] = true;
    }

    // @notice fill pools with reward comissions etc
    // @param  [uint256] _era => desired era
    function fillPools(uint256 _era) private {
        // iterate over non-processed eras
        for (uint256 i = lastUpdated + 1; i <= _era; ) {
            eraRevenue[i].done = true;
            if (eraRevenue[i].val > 0) {
                unstakingPool += eraRevenue[i].val / 10; // 10% of revenue goes to unstaking pool
                totalRevenue -= eraRevenue[i].val / 10;
                eraRevenue[i].val -= eraRevenue[i].val / 10;
            }
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

    function sync(uint _era) external onlyRole(MANAGER) {
        globalWithdraw(_era);
        claimDapp(_era);
        globalClaim(_era);
        globalStake(_era);
        globalUnstake(_era);
        fillPools(_era);
    }

    function withdrawRevenue(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalRevenue >= _amount, "Not enough funds in revenue pool");
        totalRevenue -= _amount;
        payable(msg.sender).sendValue(_amount);
    }
}
