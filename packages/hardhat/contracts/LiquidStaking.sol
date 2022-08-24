//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/DappsStaking.sol";
import "./NDistributor.sol";
import "./interfaces/IDNT.sol";
import "./interfaces/ILpHandler.sol";

/* @notice Liquid staking implementation contract
 *
 * https://docs.algem.io/algem-protocol/liquid-staking
 *
 * Features:
 * - Initializable
 * - AccessControlUpgradeable
 */
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

    struct Stake { // <== unused and will removed with next proxy update
        uint totalBalance;
        uint eraStarted;
    }
    mapping(address => Stake) public stakes; // <== unused and will removed with next proxy update

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
    mapping(uint => eraData) public eraUnstaked; // <== unused and will removed with next proxy update
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
    mapping(address => bool) public isLpToken;
    address[] public lpTokens;

    mapping(uint => uint) public eraRewards;

    uint public totalRevenue;

    mapping(address => mapping(uint => uint)) public buffer;
    mapping(address => mapping(uint => uint[])) public usersShotsPerEra;
    mapping(address => uint) public totalUserRewards;
    mapping(address => address) public lpHandlers;

    uint public eraShotsLimit;
    uint public lastClaimed;
    uint public minStakeAmount;
    uint public sum2unstake;
    bool public isUnstakes; // <== unused and will removed with next proxy update
    uint public claimingTxLimit;

    event Staked(address indexed user, uint val);
    event Unstaked(address indexed user, uint amount, bool immediate);
    event Withdrawn(address indexed user, uint val);
    event Claimed(address indexed user, uint amount);
    event UpdateError(string indexed reason);

    // events for events handle
    event ClaimStakerError(uint indexed era);
    event UnbondAndUnstakeError(uint indexed sum2unstake, uint indexed era, bytes indexed reason);
    event WithdrawUnbondedError(uint indexed _era, bytes indexed reason);
    event ClaimDappError(uint indexed amount, uint indexed era, bytes indexed reason);

    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;

    // ------------------ INIT
    // -----------------------
    function initialize(
        string memory _DNTname,
        string memory _utilName,
        address _distrAddr,
        address _dntToken
    ) public initializer {
        require(_distrAddr.isContract(), "_distrAddr should be contract address");
        require(_dntToken.isContract(), "_dntToken should be contract address");
        uint era = DAPPS_STAKING.read_current_era() - 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        setMinStakeAmount(100*10**18);
        setEraShotsLimit(15);
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();
        DNTname = _DNTname;
        utilName = _utilName;
        distr = NDistributor(_distrAddr);
        dntToken = _dntToken;

        lastUpdated = era;
        lastStaked = era;
        lastUnstaked = era;
        lastClaimed = era;

        claimingTxLimit = 5;
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

    // @notice sets min stake amount
    function setMinStakeAmount(uint _amount) public onlyRole(MANAGER) {
        minStakeAmount = _amount;
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
        require(_lp.isContract(), "_lp should be contract address");
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
        if (len % 2 == 0) return (arr[len/2] + arr[len/2 - 1])/2;
        return arr[len/2];
    }

    // @notice add amount to buffer until next era
    function addToBuffer(address _user, uint _amount) external onlyDistributor() {
        require(_user != address(0), "Zero address alarm!");
        uint era = currentEra();
        buffer[_user][era] += _amount;
    }

    function setBuffer(address _user, uint _amount) external onlyDistributor() {
        require(_user != address(0), "Zero address alarm");
        uint era = currentEra();
        buffer[_user][era] = _amount;
    }

    function setEraShotsLimit(uint _limit) public onlyRole(MANAGER) {
        eraShotsLimit = _limit;
    }

    // @notice checks if current era not claimed yet
    //         receives staker rewards for all unclaimed eras
    //         this func is called at the beginning of each era
    function claimRewards() external onlyRole(MANAGER) {
        uint era = currentEra();
        require(lastClaimed != era, "All rewards already claimed");

        uint numOfUnclaimedEras = era - lastClaimed;
        if (numOfUnclaimedEras > claimingTxLimit) {
            numOfUnclaimedEras = claimingTxLimit;
        }
        uint balBefore = address(this).balance;

        // get unclaimed rewards
        for (uint i; i < numOfUnclaimedEras; i++) {
            try DAPPS_STAKING.claim_staker(address(this)) {
                lastClaimed += 1;
            }
            catch {
                emit ClaimStakerError(lastClaimed + 1);
            }
        }

        uint balAfter = address(this).balance;
        uint coms = (balAfter - balBefore) / 10; // 10% comission to revenue and unstaking pools
        eraStakerReward[era].val += balAfter - balBefore - coms; // rewards to share between users
        rewardPool += eraStakerReward[era].val;
        totalRevenue += coms * 9 / 10; // 9% of era rewards goes to revenue pool
        unstakingPool += coms / 10; // 1% of era rewards goes to unstaking pool
    }

    // @notice saving information about users balances
    function eraShot(address _user, string memory _util, string memory _dnt) external onlyRole(MANAGER) {
        uint era = currentEra();
        require(_user != address(0), "Zero address alarm!");
        require(usersShotsPerEra[_user][era].length <= eraShotsLimit, "Too much era shots");
        require(era == lastClaimed, "Not all rewards received");

        // checks if _user haven't shots in era yet
        if (usersShotsPerEra[_user][era].length == 0) {
            uint[] memory arr = usersShotsPerEra[_user][era - 1];
            uint userLastEraRewards = arr.length > 0 ? findMedium(arr) * eraStakerReward[era].val / 10**18 : 0;

            // cutting comission part
            if (userLastEraRewards >= 10**16) {
                totalUserRewards[_user] += userLastEraRewards / 10**16 * 10**16;
            } else {
                totalUserRewards[_user] += userLastEraRewards;
            }
        }

        uint nBal = distr.getUserDntBalanceInUtil(_user, _util, _dnt);
        uint lpBal = getUserLpTokens(_user);
        uint nTotal = distr.totalDntInUtil(_util);

        uint nShare = (nBal + lpBal - buffer[_user][era]) * 10**18 / nTotal;

        // array with shares of nTokens by user per era
        usersShotsPerEra[_user][era].push(nShare);
    }

    // @notice return users rewards
    function getUserRewards(address _user) public view returns (uint) {
        return totalUserRewards[_user];
    }

    // ------------------ DAPPS_STAKING
    // --------------------------------

    // @notice ustake tokens from not yet updated eras
    // @param  [uint] _era => latest era to update
    function globalUnstake() private {
        uint era = currentEra();

        // checks if enough time has passed
        if (era * 10 < lastUnstaked * 10 + withdrawBlock * 10 / 4) {
            return;
        }

        if (sum2unstake > 0) {
            try DAPPS_STAKING.unbond_and_unstake(address(this), uint128(sum2unstake)) {
                sum2unstake = 0;
                lastUnstaked = era;
            }
            catch (bytes memory reason) {
                emit UnbondAndUnstakeError(sum2unstake, era, reason);
            }
        }
    }

    // @notice withdraw unbonded tokens
    // @param  [uint] _era => desired era
    function globalWithdraw(uint _era) private {
        uint balBefore = address(this).balance;

        try DAPPS_STAKING.withdraw_unbonded() {}
        catch (bytes memory reason) {
            emit WithdrawUnbondedError(_era, reason);
        }

        uint balAfter = address(this).balance;
        unbondedPool += balAfter - balBefore;
    }

    // @notice claim dapp rewards, transferred to dapp owner
    // @param  [uint] _era => desired era number
    function claimDapp(uint _era) private {
        for (uint i = lastUpdated + 1; i <= _era; ) {
            if (eraStakerReward[i].val > 0) {
                try DAPPS_STAKING.claim_dapp(address(this), uint128(_era)) {}
                catch (bytes memory reason) {
                    emit ClaimDappError(eraStakerReward[i].val, i, reason);
                }
            }
            unchecked { ++i; }
        }
    }

    // -------------- USER FUNCS
    // -------------------------

    // @notice updates global balances
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
        uint val = msg.value;

        require(val >= minStakeAmount, "Not enough stake amount");

        totalBalance += val;

        if (!isStaker[msg.sender]) {
            isStaker[msg.sender] = true;
            stakers.push(msg.sender);
        }

        distr.issueDnt(msg.sender, val, utilName, DNTname);

        DAPPS_STAKING.bond_and_stake(address(this), uint128(val));

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

        require(userDntBalance >= _amount, "> Not enough nASTR!");
        require(_amount > 0, "Invalid amount!");

        uint era = currentEra();
        sum2unstake += _amount;
        totalBalance -= _amount;

        distr.removeDnt(msg.sender, _amount, utilName, DNTname);

        if (_immediate) {
            // get liquidity from unstaking pool
            require(unstakingPool >= _amount, "Unstaking pool drained!");
            uint fee = _amount / 100; // 1% immediate unstaking fee
            totalRevenue += fee;
            unstakingPool -= _amount;
            payable(msg.sender).sendValue(_amount - fee);
        } else {
            uint _lag;
            if (lastUnstaked * 10 + withdrawBlock * 10 / 4 > era * 10) {
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
    function addStaker(address _addr) external onlyDistributor() {
        require(!isStaker[_addr], "Already staker");
        stakers.push(_addr);
        isStaker[_addr] = true;
    }

    // @notice manually fill the unbonded pool
    function fillUnbonded() external payable {
        require(msg.value > 0, "Provide some value!");
        unbondedPool += msg.value;
    }

    // @notice utility func for filling reward pool manually
    function fillRewardPool() external payable {
        require(msg.value > 0, "Provide some value!");
        rewardPool += msg.value;
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
        globalUnstake();
        lastUpdated = _era;
    }

    function withdrawRevenue(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalRevenue >= _amount, "Not enough funds in revenue pool");
        totalRevenue -= _amount;
        payable(msg.sender).sendValue(_amount);
    }

    // @notice      disabled revoke ownership functionality
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
        _revokeRole(role, account);
    }

    // @notice      disabled revoke ownership functionality
    function renounceRole(bytes32 role, address account) public override {
        require(
            account == _msgSender(),
            "AccessControl: can only renounce roles for self"
        );
        require(
            role != DEFAULT_ADMIN_ROLE,
            "Not allowed to renounce admin role"
        );
        _revokeRole(role, account);
    }

}
