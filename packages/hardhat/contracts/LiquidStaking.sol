//SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
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
    uint public totalBalance;
    uint public withdrawBlock;

    // @notice
    uint public unstakingPool;
    uint public rewardPool;

    // @notice distributor data
    NDistributor public distr;

    // @notice core stake struct and stakes per user, remove with next proxy update. All done via distr
    struct Stake {
        uint totalBalance;
        uint eraStarted;
    }
    mapping(address => Stake) public stakes;

    // @notice user requested withdrawals
    struct Withdrawal {
        uint val;
        uint eraReq;
        uint lag;
    }
    mapping(address => Withdrawal[]) public withdrawals;

    // @notice useful values per era
    struct eraData {
        bool done;
        uint val;
    }
    mapping(uint => eraData) public eraStaked; // total tokens staked per era
    mapping(uint => eraData) public eraUnstaked; // total tokens unstaked per era
    mapping(uint => eraData) public eraStakerReward; // total staker rewards per era
    mapping(uint => eraData) public eraRevenue; // total revenue per era

    uint public unbondedPool;

    uint public lastUpdated; // last era updated everything

    // Reward handlers
    address[] public stakers;
    address public dntToken;
    mapping(address => bool) public isStaker;

    uint public lastStaked;
    uint public lastUnstaked;

    // @notice handlers for work with LP tokens
    //         for now supposed rate 1 dnt / 1 lpToken
    mapping(address => bool) public isLpToken;
    address[] public lpTokens;

    mapping(uint => uint) public eraRewards;

    uint public totalRevenue;

    mapping(address => mapping(uint => uint)) public buffer;
    mapping(address => mapping(uint => uint[])) public usersShotsPerEra;
    mapping(address => uint) public totalUserRewards;
    mapping(address => address) public lpHandlers;

    uint public eraShotsLimit = 10;
    uint public lastClaimed;

    event Staked(address indexed user, uint val);
    event Unstaked(address indexed user, uint amount, bool immediate);
    event Withdrawn(address indexed user, uint val);
    event Claimed(address indexed user, uint amount);
    event UpdateError(string indexed reason);

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
        lastClaimed = era;
    }

    // ------------------ VIEWS
    // ------------------------
    // @notice get current era
    function currentEra() public view returns (uint) {
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

    // @notice add lp token address and handler to calc nTokens share for users
    function addPartner(address _lp, address _handler) external onlyRole(MANAGER) {
        require(!isLpToken[_lp], "Allready added");
        isLpToken[_lp] = true;
        lpTokens.push(_lp);
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

    function getLpTokens() external view returns (address[] memory) {
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
                lpHandlers[_lp] = address(0);
            }
        }
    }

    // @notice sorts the list in ascending order and return mean
    function findMedium(uint[] memory _arr) private pure returns (uint mean) {
        uint[] memory arr = _arr;
        uint len = arr.length;
        bool swapped = false;
        for (uint i; i < len - 1; i++) {
            for (uint j; j < len - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    swapped = true;
                    uint s = arr[j + 1];
                    arr[j + 1] = arr[j];
                    arr[j] = s;
                }
            }
            if (!swapped) {
                return arr[len/2];
            }
        }
        return arr[len/2];
    }

    // @notice add amount to buffer until next era
    function addToBuffer(address _user, uint _amount) external onlyDistributor() {
        uint era = currentEra();
        buffer[_user][era] += _amount;
    }

    function setBuffer(address _user, uint _amount) external onlyDistributor() {
        uint era = currentEra();
        buffer[_user][era] = _amount;
    }

    function setEraShotsLimit(uint _limit) external onlyRole(MANAGER) {
        eraShotsLimit = _limit;
    }

    // @notice saving information about users balances
    function eraShot(address _user, string memory _util, string memory _dnt) external onlyRole(MANAGER) {
        uint era = currentEra();
        require(usersShotsPerEra[_user][era].length <= eraShotsLimit, "Too much era shots");

        // checks if _user haven't shots in era yet
        if (usersShotsPerEra[_user][era].length == 0) {

            // checks if _user is first staker in the list
            // thus we get the conditions for very first shot in the era
            // then get unclaimed staker rewards and write its to state
            if (_user == stakers[0]) {
                uint numOfUnclaimedEras = era - lastClaimed;
                uint balBefore = address(this).balance;

                // get unclaimed rewards
                for (uint i; i < numOfUnclaimedEras; i++) {
                    try DAPPS_STAKING.claim_staker(address(this)) {}
                    catch Error(string memory reason) {
                        emit UpdateError(reason);
                    }
                }

                lastClaimed = era;
                uint balAfter = address(this).balance;
                uint coms = (balAfter - balBefore) / 100; // 1% comission to revenue pool
                eraStakerReward[era].val += balAfter - balBefore - coms; // rewards to share between users
                eraRevenue[era].val += coms;
                totalRevenue += coms;
            }

            uint[] memory arr = usersShotsPerEra[_user][era - 1];
            uint userLastEraRewards = findMedium(arr) * eraStakerReward[era].val / 10**18;
            totalUserRewards[_user] += userLastEraRewards;
        }

        uint nBal = distr.getUserDntBalanceInUtil(_user, _util, _dnt);
        uint lpBal = getUserLpTokens(_user);
        uint nTotal = distr.totalDntInUtil(_util);

        uint nShare = ((nBal + lpBal - buffer[_user][era]) / nTotal) * 10**18;

        // array with shares of nTokens by user per era
        usersShotsPerEra[_user][era].push(nShare);
    }

    // @notice return users rewards
    function getUserRewards(address _user) public view returns (uint) {
        return totalUserRewards[_user];
    }

    // ------------------ DAPPS_STAKING
    // --------------------------------

    // @notice stake tokens from not yet updated eras
    // @param  [uint] _era => latest era to update
    function globalStake(uint _era) private {
        uint128 sum2stake = 0;

        for (uint i = lastStaked + 1; i <= _era; ) {
            sum2stake += uint128(eraStaked[i].val);
            eraStaked[i].done = true;
            unchecked {
                ++i;
            }
        }

        if (sum2stake > 0) {
            try DAPPS_STAKING.bond_and_stake(address(this), sum2stake) {}
            catch Error(string memory reason) {
                emit UpdateError(reason);
            }
        }
        lastStaked = _era;
    }

    // @notice ustake tokens from not yet updated eras
    // @param  [uint] _era => latest era to update
    function globalUnstake() private {
        uint128 sum2unstake = 0;
        uint era = currentEra();
        if (era * 10 <= lastUnstaked * 10 + withdrawBlock * 10 / 4) {
            return;
        }
        for (uint i = lastUnstaked; i <= era; ) {
            eraUnstaked[i].done = true;
            sum2unstake += uint128(eraUnstaked[i].val);
            unchecked {
                ++i;
            }
        }

        if (sum2unstake > 0) {
            try DAPPS_STAKING.unbond_and_unstake(address(this), sum2unstake) {}
            catch Error(string memory reason) {
                require(keccak256(abi.encodePacked(reason)) != keccak256(abi.encodePacked("TooManyUnlockingChunks")), "Too many chunks");
                emit UpdateError(reason);
            }
        }
        lastUnstaked = era;
    }

    // @notice withdraw unbonded tokens
    // @param  [uint] _era => desired era
    function globalWithdraw(uint _era) private {
        bool isUnstaked;

        // checks if there is unstaked eras
        for (uint i = lastUpdated + 1; i <= _era; ) {
            if (eraUnstaked[i - withdrawBlock].val != 0) {
                isUnstaked = true;
                break;
            }
            unchecked { ++i; }
        }

        uint p = address(this).balance;

        // if there is unstaked eras, withdraw unbonded
        // and reset all eraUnstaked
        if (isUnstaked) {
            try DAPPS_STAKING.withdraw_unbonded() {
                for (uint i = lastUpdated + 1; i <= _era; ) {
                    if (eraUnstaked[i - withdrawBlock].val != 0) {
                        eraUnstaked[i - withdrawBlock].val = 0;
                    }
                    unchecked { ++i; }
                }
            } catch Error(string memory reason) {
                require(keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("NothingToWithdraw")), "Error with withdraw_unbonded");
                emit UpdateError(reason);
            }
        }
        uint a = address(this).balance;
        unbondedPool += a - p;
    }

    // @notice claim dapp rewards, transferred to dapp owner
    // @param  [uint] _era => desired era number
    function claimDapp(uint _era) private {
        for (uint i = lastUpdated + 1; i <= _era; ) {
            try DAPPS_STAKING.claim_dapp(address(this), uint128(_era)) {}
            catch Error(string memory reason) {
                require(keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("AlreadyClaimedInThisEra")), "Error with withdraw_unbonded");
                emit UpdateError(reason);
            }
            unchecked { ++i; }
        }
    }

    // -------------- USER FUNCS
    // -------------------------

    // @notice updates global balances, stakes/unstakes etc
    modifier updateAll() {
        uint era = currentEra() - 1; // last era to update
        if (lastUpdated != era) {
            updates(era);
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
        uint era = currentEra();
        uint val = msg.value;

        totalBalance += val;
        eraStaked[era].val += val;

        s.totalBalance += val;
        s.eraStarted = s.eraStarted == 0 ? era : s.eraStarted;

        if (!isStaker[msg.sender]) {
            isStaker[msg.sender] = true;
            stakers.push(msg.sender);
        }

        distr.issueDnt(msg.sender, val, utilName, DNTname);
        globalStake(era - 1);
        emit Staked(msg.sender, val);
    }

    // @notice unstake tokens from app, loose DNT
    // @param  [uint] _amount => amount of tokens to unstake
    // @param  [bool] _immediate => receive tokens from unstaking pool, create a withdrawal otherwise
    function unstake(uint _amount, bool _immediate) external updateAll {
        uint userDntBalance = distr.getUserDntBalanceInUtil(
            msg.sender,
            utilName,
            DNTname
        );
        Stake storage s = stakes[msg.sender];

        require(userDntBalance >= _amount, "> Not enough nASTR!");
        require(_amount > 0, "Invalid amount!");

        uint era = currentEra();
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
            uint fee = _amount / 100; // 1% immediate unstaking fee
            eraRevenue[era].val += fee;
            totalRevenue += fee;
            unstakingPool -= _amount;
            payable(msg.sender).sendValue(_amount - fee);
        } else {
            uint _lag;
            if (lastUnstaked * 10 + withdrawBlock * 10 / 4 - era * 10 > 0) {
                _lag = lastUnstaked * 10 + withdrawBlock * 10 / 4 - era * 10;
            }
            // create a withdrawal to withdraw_unbonded later
            withdrawals[msg.sender].push(
                Withdrawal({val: _amount, eraReq: era, lag: _lag})
            );
        }

        emit Unstaked(msg.sender, _amount, _immediate);
    }

    // @notice claim rewards by user
    // @param  [uint] _amount => amount of claimed reward
    function claim(uint _amount) external updateAll {
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
    // @param  [uint] _id => withdrawal index
    function withdraw(uint _id) external updateAll {
        Withdrawal storage withdrawal = withdrawals[msg.sender][_id];
        uint val = withdrawal.val;
        uint era = currentEra();

        require(withdrawal.eraReq != 0, "Withdrawal already claimed");
        require(era * 10 - withdrawal.eraReq * 10 >= withdrawBlock * 10 + withdrawal.lag, "Not enough eras passed!");
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
        uint stakerDntBalance = distr.getUserDntBalanceInUtil(_addr, _util, _dnt);
        stakes[_addr].totalBalance = stakerDntBalance;
        stakers.push(_addr);
        isStaker[_addr] = true;
    }

    // @notice fill pools with reward comissions etc
    // @param  [uint] _era => desired era
    function fillPools(uint _era) private {
        // iterate over non-processed eras
        for (uint i = lastUpdated + 1; i <= _era; ) {
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

    // @notice utility function in case of excess gas consumption
    function sync(uint _era) external onlyRole(MANAGER) {
        require(_era > lastUpdated && _era < currentEra(), "Wrong era range");
        updates(_era);
    }

    function updates(uint _era) private {
        globalWithdraw(_era);
        claimDapp(_era);
        fillPools(_era);
        globalUnstake();
        lastUpdated = _era;
    }

    function withdrawRevenue(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalRevenue >= _amount, "Not enough funds in revenue pool");
        totalRevenue -= _amount;
        payable(msg.sender).sendValue(_amount);
    }
}
