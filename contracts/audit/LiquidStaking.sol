//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/DappsStaking.sol";
import "./NDistributor.sol";
import "./interfaces/IDNT.sol";
import "./interfaces/IPartnerHandler.sol"; /* 1 -> 1.5 will removed with next proxy update */
import "./interfaces/INFTDistributor.sol";
import "./interfaces/IAdaptersDistributor.sol";

contract LiquidStaking is AccessControl {
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
    address[] public stakers;
    /* unused and will removed with next proxy update */address public dntToken;
    mapping(address => bool) public isStaker;

    /* unused and will removed with next proxy update */uint public lastStaked;
    uint public lastUnstaked;

    /* unused and will removed with next proxy update */// @notice handlers for work with LP tokens
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
    /* unused and will removed with next proxy update */uint public sum2unstake;
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

    using Address for address payable;
    using Address for address;

     constructor(
        string memory _dntName,
        string memory _dntUtil,
        address _distrAddr
    ) {
        require(_distrAddr.isContract(), "_distrAddr should be contract address");
        DNTname = _dntName;
        utilName = _dntUtil;

        uint256 era = DAPPS_STAKING.read_current_era() - 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        setMinStakeAmount(10);
        minStakeAmount = 10;
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();

        distr = NDistributor(_distrAddr);

        lastUpdated = era;
        lastStaked = era;
        lastUnstaked = era;
        lastClaimed = era;

        dappsList.push(_dntUtil);
        haveUtility[_dntUtil] = true;
        isActive[_dntUtil] = true;
        dapps[_dntUtil].dappAddress = address(this);
    }

    function initialize2(address _nftDistr, address _adaptersDistr) external onlyRole(MANAGER) {
        nftDistr = INFTDistributor(_nftDistr);
        adaptersDistr = IAdaptersDistributor(_adaptersDistr);

        _grantRole(MANAGER, _nftDistr);
        _grantRole(MANAGER, _adaptersDistr);

        dapps[utilName].sum2unstake = sum2unstake;
        dapps[utilName].stakedBalance = distr.totalDntInUtil(utilName); 
        lastEraTotalBalance = distr.totalDnt(DNTname);
    }

    // --------------------------------------------------------------------
    // Modifiers ----------------------------------------------------------
    // -------------------------------------------------------------------- 

    /// @notice check arrays length
    /// @param _utilities => utilities to check length
    /// @param _amounts => amounts to check length
    modifier checkArrays(string[] memory _utilities, uint256[] memory _amounts) {
        require(_utilities.length > 0, "No one utility selected");
        require(_utilities.length == _amounts.length, "Incorrect arrays length");
        _;
    }   

    /// @notice only distributor modifier
    modifier onlyDistributor() {
        require(msg.sender == address(distr) || msg.sender == address(adaptersDistr), "Only for distributor!");
        _;
    }

    /// @notice updates user rewards
    modifier updateRewards(address _user, string[] memory _utilities) {
        uint256 l =_utilities.length;

        // harvest rewards for current balances
        for (uint256 i; i < l; i++) harvestRewards(_utilities[i], _user);
        _;
        // update balances in utils
        for (uint256 i; i < l; i++) _updateUserBalanceInUtility(_utilities[i], _user);
    }

    /// @notice updates global balances
    modifier updateAll() {
        uint256 _era = currentEra();
        if (lastUpdated != _era) {
            updates(_era);
        }
        _;
    }

    // --------------------------------------------------------------------
    // Users functions ----------------------------------------------------
    // --------------------------------------------------------------------

    /// @notice stake native tokens, receive equal amount of DNT
    /// @param _utilities => dapps utilities
    /// @param _amounts => amounts of tokens to stake
    function stake(string[] memory _utilities, uint256[] memory _amounts) 
    external payable 
    checkArrays(_utilities, _amounts) 
    updateAll {
        uint256 value = msg.value;

        uint256 l = _utilities.length;
        uint256 _stakeAmount;
        for (uint256 i; i < l; i++) {
            require(isActive[_utilities[i]], "Dapp not active");
            require(_amounts[i] >= minStakeAmount, "Not enough stake amount");

            _stakeAmount += _amounts[i];
        }
        require(_stakeAmount > 0, "Incorrect amounts");
        require(value >= _stakeAmount, "Incorrect value");

        eraBuffer[0] += _stakeAmount;
        uint256 _era = currentEra();

        if (!isStaker[msg.sender]) {
            isStaker[msg.sender] = true;
            stakers.push(msg.sender);
        }

        totalBalance += _stakeAmount;
        totalRevenue += value - _stakeAmount;

        for (uint256 i; i < l; i++) {
            if (dapps[_utilities[i]].stakers[msg.sender].lastClaimedEra == 0)
                dapps[_utilities[i]].stakers[msg.sender].lastClaimedEra = _era + 1;

            if (_amounts[i] > 0) {
                string memory _utility = _utilities[i];

                DAPPS_STAKING.bond_and_stake(dapps[_utility].dappAddress, uint128(_amounts[i]));
                distr.issueDnt(msg.sender, _amounts[i], _utility, DNTname);

                dapps[_utility].stakedBalance += _amounts[i];

                emit StakedInUtility(msg.sender, _utility, _amounts[i]);
            }
        }
        emit Staked(msg.sender, _stakeAmount);
    }

    /// @notice unstake tokens from dapps
    /// @param _utilities => dapps utilities
    /// @param _amounts => amounts of tokens to unstake
    /// @param _immediate => receive tokens from unstaking pool, create a withdrawal otherwise
    function unstake(string[] memory _utilities, uint256[] memory _amounts, bool _immediate) 
    external
    checkArrays(_utilities, _amounts) 
    updateAll {
        uint256 totalUnstaked;
        uint256 era = currentEra(); 
        
        uint256 l = _utilities.length;
        for (uint256 i; i < l; i++) {
            require(haveUtility[_utilities[i]], "Unknown utility");
            if (_amounts[i] > 0) {
                string memory _utility = _utilities[i];
                uint256 _amount = _amounts[i];

                uint256 userDntBalance = distr.getUserDntBalanceInUtil(
                    msg.sender,
                    _utility,
                    DNTname
                );
                require(userDntBalance >= _amount, "Not enough nASTR in utility");
                
                Dapp storage dapp = dapps[_utility];
                harvestRewards(_utility, msg.sender);
                _updatePreviousEra(dapp, era, _amount);

                dapp.sum2unstake += _amount;
                totalBalance -= _amount;
                dapp.stakedBalance -= _amount;

                distr.removeDnt(msg.sender, _amount, _utility, DNTname);

                if (_immediate) {
                    require(unstakingPool >= _amount, "Unstaking pool drained!");
                    uint256 fee = _amount / 100; // 1% immediate unstaking fee
                    totalRevenue += fee;
                    unstakingPool -= _amount;
                    payable(msg.sender).sendValue(_amount - fee);
                } else {
                    uint256 _lag;

                    if (lastUnstaked * 10 + withdrawBlock * 10 / 4 > era * 10) {
                        _lag = lastUnstaked * 10 + withdrawBlock * 10 / 4 - era * 10;
                    }
                    // create a withdrawal to withdraw_unbonded later
                    withdrawals[msg.sender].push(
                        Withdrawal({val: _amount, eraReq: era, lag: _lag})
                    );
                }
                totalUnstaked += _amount;
                emit UnstakedFromUtility(msg.sender, _utility, _amount, _immediate);
            }
        }
        if (totalUnstaked > 0) {
            eraBuffer[1] += totalUnstaked;
            emit Unstaked(msg.sender, totalUnstaked, _immediate);
        }
    }

    /// @notice claim user rewards from utilities
    /// @param _utilities => utilities from claim
    /// @param _amounts => amounts from claim
    function claim(string[] memory _utilities, uint256[] memory _amounts)
    public
    checkArrays(_utilities, _amounts)
    updateAll 
    updateRewards(msg.sender, _utilities) {
        _claim(_utilities, _amounts);
    }

    /// @notice claim all user rewards from all utilities (without adapters)
    function claimAll() external updateAll {
        string[] memory _utilities = distr.listUserUtilitiesInDnt(msg.sender, DNTname);

        uint256 l = _utilities.length;
        uint256[] memory _amounts = new uint256[](l);

        // update user rewards and push to _amounts[]
        for (uint256 i; i < l; i++) {
            harvestRewards(_utilities[i], msg.sender);
            _amounts[i] = dapps[_utilities[i]].stakers[msg.sender].rewards;
        }
        _claim(_utilities, _amounts);

        // update last user balance
        for (uint256 i; i < l; i++)
            _updateUserBalanceInUtility(_utilities[i], msg.sender);
    }

    /// @notice finish previously opened withdrawal
    /// @param _id => withdrawal index
    function withdraw(uint _id) external updateAll() {
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
    
    // --------------------------------------------------------------------
    // Every eras functions -----------------------------------------------
    // --------------------------------------------------------------------

    /// @notice global updates function
    /// @param _era => era to update
    function updates(uint256 _era) private {
        globalWithdraw(_era);
        claimFromDapps(_era);
        claimDapp(_era);
        globalUnstake(_era);
        lastUpdated = _era;
    }

    /// @notice claim staker rewards from all dapps
    /// @param _era => latest era to claim
    function claimFromDapps(uint256 _era) private {
        if (lastUpdated >= _era) return;  

        uint256 l = dappsList.length;

        /// @custom:defimoon-note separately, we collect rewards for the first unclaimed era and for all the rest.
        /// this is due to the fact that <lastEtaTotalBalance> is updated at the moment of the previous era, 
        /// and if the <updates()> function is not called in the next era, then the balance staked in the current era 
        /// will not participate in the <accumulatedRewardsPerShare> calculation.
        /// Therefore, to avoid such situations, the balance for subsequent eras is written to <eraBuffer>.
        uint256 balance1 = address(this).balance;
        for (uint256 i; i < l; i++) _claimFromDapp(dappsList[i], lastUpdated, lastUpdated + 1);
        uint256 balance2 = address(this).balance;
        uint256[2] memory rewards;
        rewards[0] = balance2 - balance1;

        for (uint256 i; i < l; i++) _claimFromDapp(dappsList[i], lastUpdated + 1, _era);
        rewards[1] = address(this).balance - balance2;

        uint256 receivedRewards = rewards[0] + rewards[1];

        uint256 eras = _era - lastUpdated;
        /// @custom:defimoon-note the specified implementation may throw an error when eraBuffer[1] > eraBuffer[0]
        /// *--
        /// $ uint256 allErasBalance = lastEraTotalBalance * eras + (eraBuffer[0] - eraBuffer[1]) * (eras - 1);
        /// *--
        uint256 allErasBalance = lastEraTotalBalance * eras + eraBuffer[0] * (eras - 1) - eraBuffer[1] * (eras - 1);
        
        if (allErasBalance > 0) {
            uint256[2] memory erasData = nftDistr.getErasData(lastUpdated - 1, _era - 1);
            uint256[2] memory fisrtData = nftDistr.getEra(lastUpdated - 1);

            uint256 rewardsK;
            uint256 nftRevenue;
            uint256 defaultRevenue;

            /// @custom:defimoon-note <accumulatedRewardsPerShare> stores the coefficient of accrued rewards from staked balance.
            /// The coefficient is calculated without taking into account any fees that are calculated when the user claims the rewards.
            if (lastEraTotalBalance > 0) {
                rewardsK = rewards[0] * REWARDS_PRECISION / lastEraTotalBalance;
                nftRevenue += rewardsK * fisrtData[1] / (100 * REWARDS_PRECISION);
                defaultRevenue += rewardsK * REVENUE_FEE * (lastEraTotalBalance - fisrtData[0]) / (100 * REWARDS_PRECISION);
                accumulatedRewardsPerShare[lastUpdated] = rewardsK;
            }
            if (allErasBalance > lastEraTotalBalance) {
                rewardsK = rewards[1] * REWARDS_PRECISION / (allErasBalance - lastEraTotalBalance);
                nftRevenue += rewardsK * (erasData[1] - fisrtData[1]) / (100 * REWARDS_PRECISION);
                defaultRevenue += rewardsK * REVENUE_FEE * (allErasBalance - lastEraTotalBalance - (erasData[0]  - fisrtData[0])) / (100 * REWARDS_PRECISION);
                for (uint256 i = lastUpdated + 1; i < _era; ) {
                    accumulatedRewardsPerShare[i] = rewardsK;
                    unchecked { ++i; }
                }
            } 

            uint256 toUnstaking = receivedRewards / 100;  // 1% of era rewards goes to unstaking pool
            uint256 totalReceived = receivedRewards - nftRevenue - defaultRevenue - toUnstaking;

            totalRevenue += nftRevenue + defaultRevenue; // 9% of era reward s goes to revenue pool
            unstakingPool += toUnstaking;
            rewardPool += totalReceived;

        } else totalRevenue += receivedRewards;
        
        (eraBuffer[0], eraBuffer[1]) = (0, 0);
        // update last era balance
        // last era balance = balance that participates in the current era
        lastEraTotalBalance = distr.totalDnt(DNTname);
    }   

    /// @notice claim staker rewards from utility
    /// @param _utility => utility
    /// @param _eraBegin => first era to claim
    /// @param _eraEnd => latest era to claim
    function _claimFromDapp(string memory _utility, uint256 _eraBegin, uint256 _eraEnd) private {
        // check active status
        uint256 eraEnd = isActive[_utility] ? _eraEnd : deactivationEra[_utility];
        for (uint256 i = _eraBegin; i < eraEnd; ) {
            try DAPPS_STAKING.claim_staker(dapps[_utility].dappAddress) {
                emit ClaimStakerSuccess(i, i);
            } catch (bytes memory reason) {
                emit ClaimStakerError(_utility, i, reason);
            }
            unchecked { ++i; }
        }
    } 

    /// @notice claim dapp rewards for this contract
    /// @dev the function collects rewards only for the LiquidStaking contract
    function claimDapp(uint _era) private {
        for (uint256 i = lastUpdated; i < _era; ) {       
            try DAPPS_STAKING.claim_dapp(address(this), uint128(i)) {}
            catch (bytes memory reason) {
                emit ClaimDappError(accumulatedRewardsPerShare[i], i, reason);
            }
            unchecked { ++i; }
        }
    }

    /// @notice withdraw unbonded tokens
    /// @param _era => desired era
    function globalWithdraw(uint256 _era) private {
        uint256 balanceBefore = address(this).balance;

        try DAPPS_STAKING.withdraw_unbonded() {
            emit WithdrawUnbondedSuccess(_era);
        }
        catch (bytes memory reason) {
            emit WithdrawUnbondedError(_era, reason);
        }

        uint256 balanceAfter = address(this).balance;
        unbondedPool += balanceAfter - balanceBefore;
    }

    /// @notice ustake tokens from not yet updated eras from all dapps
    /// @param _era => latest era to update
    function globalUnstake(uint256 _era) private {
        if (_era * 10 < lastUnstaked * 10 + withdrawBlock * 10 / 4) return;
        
        // unstake from all dapps
        uint256 l = dappsList.length;
        for (uint256 i; i < l; ) {
            _globalUnstake(dappsList[i], _era);
            unchecked { ++i; }
        }

        lastUnstaked = _era;
    }

    /// @notice ustake tokens from not yet updated eras from utility
    /// @param _utility => utility to unstake
    /// @param _era => latest era to update
    function _globalUnstake(string memory _utility, uint256 _era) private {
        Dapp storage dapp = dapps[_utility];

        if (dapp.sum2unstake == 0) return;
        if (!isActive[_utility] && _era > deactivationEra[_utility]) return;

        try DAPPS_STAKING.unbond_and_unstake(dapp.dappAddress, uint128(dapp.sum2unstake)) {
            emit UnbondAndUnstakeSuccess(_era, sum2unstake);
            dapp.sum2unstake = 0;
        } catch (bytes memory reason) {
            emit UnbondAndUnstakeError(_utility, dapp.sum2unstake, _era, reason);
        }
    }

    // --------------------------------------------------------------------
    // Management functions // For ADMIN and MANAGER roles ----------------
    // --------------------------------------------------------------------

    /// @notice add new partner dapp
    /// @param _utility => dapp utility name
    /// @param _dapp => dapp address
    function addDapp(string memory _utility, address _dapp) external onlyRole(MANAGER) {
        require(_dapp != address(0), "Incorrect dapp address");
        require(!haveUtility[_utility], "Utility already added");

        distr.addUtility(_utility);
        dappsList.push(_utility);
        haveUtility[_utility] = true;
        isActive[_utility] = true;
        dapps[_utility].dappAddress = _dapp;
    }
    
    /// @notice activate or deactivate interaction with dapp
    /// @param _utility => dapp utility name
    /// @param _state => state variable
    function setDappStatus(string memory _utility, bool _state) external onlyRole(MANAGER) {
        require(haveUtility[_utility], "No such this utility");
        isActive[_utility] = _state;
        if (!_state) {
            // set deactivation era
            // if dapp is not active - cant stake, but can unstake and withdraw
            deactivationEra[_utility] = currentEra() + withdrawBlock;
        }
    }

    /// @notice utility function in case of excess gas consumption
    function sync(uint _era) external onlyRole(MANAGER) {
        require(_era > lastUpdated && _era <= currentEra(), "Wrong era range");
        updates(_era);

        emit Synchronization(msg.sender, _era);
    }
    
    /// @notice utility harvest function
    function syncHarvest(address _user, string[] memory _utilities) 
    external
    onlyRole(MANAGER)
    updateRewards(_user, _utilities) {}

    /// @notice sets min stake amount
    /// @param _amount => new min stake amount
    function setMinStakeAmount(uint _amount) public onlyRole(MANAGER) {
        require(_amount > 0, "Should be greater than zero!");
        minStakeAmount = _amount;
        emit SetMinStakeAmount(msg.sender, _amount);
    }
    
    // /// @notice manually fill the unbonded pool
    // function fillUnbonded() external payable {
    //     require(msg.value > 0, "Provide some value!");
    //     unbondedPool += msg.value;

    //     emit FillUnbonded(msg.sender, msg.value);
    // }

    // /// @notice utility func for filling reward pool manually
    // function fillRewardPool() external payable {
    //     require(msg.value > 0, "Provide some value!");
    //     rewardPool += msg.value;

    //     emit FillRewardPool(msg.sender, msg.value);
    // }

    // /// @notice manually fill the unstaking pool
    // function fillUnstaking() external payable {
    //     require(msg.value > 0, "Provide some value!");
    //     unstakingPool += msg.value;

    //     emit FillUnstaking(msg.sender, msg.value);
    // }

    // /// @notice withdraw revenu function
    // function withdrawRevenue(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     require(totalRevenue >= _amount, "Not enough funds in revenue pool");
    //     totalRevenue -= _amount;
    //     payable(msg.sender).sendValue(_amount);

    //     emit WithdrawRevenue(_amount);
    // }

    // /// @notice disabled revoke ownership functionality
    // function revokeRole(bytes32 role, address account)
    //     public
    //     override
    //     onlyRole(getRoleAdmin(role))
    // {
    //     require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
    //     _revokeRole(role, account);
    // }

    // /// @notice disabled revoke ownership functionality
    // function renounceRole(bytes32 role, address account) public override {
    //     require(
    //         account == _msgSender(),
    //         "AccessControl: can only renounce roles for self"
    //     );
    //     require(
    //         role != DEFAULT_ADMIN_ROLE,
    //         "Not allowed to renounce admin role"
    //     );
    //     _revokeRole(role, account);
    // }
    
    // --------------------------------------------------------------------
    // Management functions // For Distributors contracts -----------------
    // --------------------------------------------------------------------
    
    /// @notice add new staker and save balances
    /// @param  _addr => user to add
    /// @param  _utility => user utility
    function addStaker(address _addr, string memory _utility) external onlyDistributor() {
        if (!isStaker[msg.sender]) {
            stakers.push(_addr);
            isStaker[_addr] = true;
        }
        if (dapps[_utility].stakers[msg.sender].lastClaimedEra == 0)
            dapps[_utility].stakers[msg.sender].lastClaimedEra = currentEra() + 1;
    }

    /// @notice update last user balance
    /// @param _utility => utility
    /// @param _user => user address
    function updateUserBalanceInUtility(string memory _utility, address _user) external onlyDistributor {
        _updateUserBalanceInUtility(_utility, _user);
    }

    /// @notice function to update last user balance in adapters
    /// @param _utility => "AdaptersUtility" utility
    /// @param _user => user address
    function updateUserBalanceInAdapter(string memory _utility, address _user) external onlyDistributor {
        require(_user != address(0), "Zero address alarm!");
        uint256 _amount = adaptersDistr.getUserBalanceInAdapters(_user);
        _updateUserBalance(_utility, _user, _amount);
    }

    // --------------------------------------------------------------------
    // Private logic functions // -----------------------------------------
    // --------------------------------------------------------------------

    /// @notice function to update last user balance in utility
    /// @param _utility => utility
    /// @param _user => user address
    function _updateUserBalanceInUtility(string memory _utility, address _user) private  {
        require(_user != address(0), "Zero address alarm!");
        uint256 _amount = distr.getUserDntBalanceInUtil(_user, _utility, DNTname);
        _updateUserBalance(_utility, _user, _amount);
    }

    /// @notice function to update user balance in next era
    /// @param _utility => utility
    /// @param _user => user address
    /// @param _amount => new era balance
    function _updateUserBalance(string memory _utility, address _user, uint256 _amount) private {
        uint _era = currentEra() + 1;

        Staker storage staker = dapps[_utility].stakers[_user];

        if (dapps[_utility].stakers[_user].lastClaimedEra == 0)
            dapps[_utility].stakers[_user].lastClaimedEra = _era;

        // add to mapping   
        staker.eraBalance[_era] = _amount;
        staker.isZeroBalance[_era] = _amount > 0 ? false : true;
    }

    /// @notice function to update the user's balance upon unstaking in the current era
    /// @param dapp => <Dapp struct> to update user balance.
    /// @param era => current era.
    /// @param amount => unstaking amount.
    function _updatePreviousEra(Dapp storage dapp, uint256 era, uint256 amount) private {
        if (!dapp.stakers[msg.sender].isZeroBalance[era]) {
            if (dapp.stakers[msg.sender].eraBalance[era] > amount) dapp.stakers[msg.sender].eraBalance[era] -= amount;
            else {
                dapp.stakers[msg.sender].eraBalance[era] = 0;
                dapp.stakers[msg.sender].isZeroBalance[era] = true;
            }   
        }
    }

    /// @notice claim rewards by user utilities
    /// @param _utilities => utilities from claim
    /// @param _amounts => amounts from claim
    function _claim(string[] memory _utilities, uint256[] memory _amounts) 
    private {
        uint256 l = _utilities.length;
        uint256 transferAmount;

        for (uint256 i; i < l; i++) {
            if (_amounts[i] > 0) {
                Dapp storage dapp = dapps[_utilities[i]];
                require(
                    dapp.stakers[msg.sender].rewards >= _amounts[i],    
                    "Not enough rewards!"
                );
                require(rewardPool >= _amounts[i], "Rewards pool drained");
                
                rewardPool -= _amounts[i];
                dapp.stakers[msg.sender].rewards -= _amounts[i];
                totalUserRewards[msg.sender] -= _amounts[i];
                transferAmount += _amounts[i];

                emit ClaimedFromUtility(msg.sender, _utilities[i], _amounts[i]);
            }
        }

        require(transferAmount > 0, "Nothing to cliam");
        payable(msg.sender).sendValue(transferAmount);

        emit Claimed(msg.sender, transferAmount);
    }
    
    /// @notice harvest user rewards
    /// @param _utility => utility to harvest
    /// @param _user => user address
    function harvestRewards(string memory _utility, address _user) private {
        // calculate unclaimed user rewards
        (uint256[2] memory userData, uint8 newEraComission, uint256 userEraBalance, bool _updateUser) = calcUserRewards(_utility, _user);
        if (_updateUser) {
            // update all structures for storing balances and fees in specific eras to actual values
            dapps[_utility].stakers[_user].eraBalance[lastUpdated] = userEraBalance;
            dapps[_utility].stakers[_user].isZeroBalance[lastUpdated] = userEraBalance > 0 ? false : true;
            nftDistr.updateUser(_utility, _user, lastUpdated - 1, userData[0]);
            nftDistr.updateUserFee(_user, newEraComission, lastUpdated - 1);
        } 

        dapps[_utility].stakers[_user].lastClaimedEra = lastUpdated;

        if (userData[1] == 0) return;

        // update user rewards
        dapps[_utility].stakers[_user].rewards += userData[1];
        totalUserRewards[_user] += userData[1];
        emit HarvestRewards(_user, _utility, userData[1]);
    }

    /// @notice clculate unclaimed user rewards from utility
    /// @param _utility => utility name
    /// @param _user => user address
    /// @return userData => [0] - last user balance with nft | [1] - total rewards
    /// @return userEraFee => last user comission
    /// @return needUpdated => flag to update user data; if true - need to update
    /// @custom:defimoon-note all balance and fee calculations are done inside the function 
    /// * because we need the function to be a <view> so that we can calculate 
    /// * the most up-to-date rewards for the user without the need for a claim
    function calcUserRewards(string memory _utility, address _user) private view returns (uint256[2] memory userData, uint8, uint256, bool) {
        Staker storage user = dapps[_utility].stakers[_user];
    
        if (user.lastClaimedEra >= lastUpdated || user.lastClaimedEra == 0) return (userData, 0, 0, false);

        (userData[0], ) = nftDistr.getUserEraBalance(_utility, _user, user.lastClaimedEra - 1);
        uint8 userEraFee = nftDistr.getUserEraFee(_user, user.lastClaimedEra - 1);
        if (userEraFee == 0) userEraFee = REVENUE_FEE;

        uint256 userEraBalance = user.eraBalance[user.lastClaimedEra];
        bool isUnique = nftDistr.isUnique(_utility);
        
        for (uint256 i = user.lastClaimedEra; i < lastUpdated; ) {
            if (userEraBalance > 0) {
                // calcutating user rewards with user era fee
                if (userData[0] > 0 && isUnique) userEraFee = nftDistr.getBestUtilFee(_utility, userEraFee);
                uint256 userEraRewards = userEraBalance * accumulatedRewardsPerShare[i] / REWARDS_PRECISION;
                userData[1] += userEraRewards * (100 - userEraFee - UNSTAKING_FEE) / 100;
            }
            
            // using <eraBalance> and <isZeroBalance> determine the user's balance in the next era
            if (user.eraBalance[i + 1] == 0) {
                if (user.isZeroBalance[i + 1]) userEraBalance = 0;
            } else userEraBalance = user.eraBalance[i + 1];

            // determine the user's balance with nft in the next era
            (uint256 _userBalanceWithNft, bool _isZeroBalanceWithNft) = nftDistr.getUserEraBalance(_utility, _user, i);
            if (_userBalanceWithNft == 0) {
                if (_isZeroBalanceWithNft) userData[0] = 0;
            } else userData[0] = _userBalanceWithNft;

            // determine the user's fee in the next era
            uint8 _userNextEraFee = nftDistr.getUserEraFee(_user, i);
            if (_userNextEraFee > 0) userEraFee = _userNextEraFee;
            unchecked { ++i; }
        }
        return (userData, userEraFee, userEraBalance, true);
    }

    // --------------------------------------------------------------------
    // View functions // --------------------------------------------------
    // --------------------------------------------------------------------

    /// @notice get current era
    function currentEra() public view returns (uint) {
        return DAPPS_STAKING.read_current_era();
    }

    /// @notice return stakers array
    function getStakers() external view returns (address[] memory) {
        return stakers;
    }   

    /// @notice preview all eser rewards from utility at current era
    /// @param _utility => utility
    /// @param _user => user address
    /// @return userRewards => unclaimed user rewards from utility
    function previewUserRewards(string memory _utility, address _user) external view returns (uint256) {
        (uint256[2] memory userData, , , ) = calcUserRewards(_utility, _user);
        return userData[1] + dapps[_utility].stakers[_user].rewards;
    }
    
    /// @notice return users rewards
    /// @param _user => user address
    function getUserRewards(address _user) public view returns (uint) {
        return totalUserRewards[_user];
    }

    /// @notice returns user active withdrawals
    function getUserWithdrawals() external view returns (Withdrawal[] memory) {
        return withdrawals[msg.sender];
    }

    // --------------------------------------------------------------------
    // Misk 1 -> 1.5 // Will removed with next proxy update ---------------
    // Functions for a smooth transition from handlers to adapters --------
    // --------------------------------------------------------------------
    
    // /// @notice iterate by each partner address and get user rewards from handlers
    // /// @param _user shows share of user in nTokens
    // function getUserLpTokens(address _user) public view returns (uint amount) {
    //     if (partners.length == 0) return 0;
    //     for (uint i; i < partners.length; i++) {
    //         amount += IPartnerHandler(partners[i]).calc(_user);
    //     }
    // }
    
    // /// @notice sorts the list in ascending order and return mean
    // /// @param _arr array with user's shares
    // function findMedian(uint[] memory _arr) private pure returns (uint mean) {
    //     uint[] memory arr = _arr;
    //     uint len = arr.length;
    //     bool swapped = false;
    //     for (uint i; i < len - 1; i++) {
    //         for (uint j; j < len - i - 1; j++) {
    //             if (arr[j] > arr[j + 1]) {
    //                 swapped = true;
    //                 uint s = arr[j + 1];
    //                 arr[j + 1] = arr[j];
    //                 arr[j] = s;
    //             }
    //         }
    //         if (!swapped) {
    //             return arr[len/2];
    //         }
    //     }
    //     if (len % 2 == 0) return (arr[len/2] + arr[len/2 - 1])/2;
    //     return arr[len/2];
    // }

    // /// @notice saving information about users balances
    // /// @param _user user's address
    // function eraShot(address _user) external onlyRole(MANAGER) {
    //     require(_user != address(0), "Zero address alarm!");        
        
    //     uint era = currentEra();
    //     require(usersShotsPerEra[_user][era].length <= eraShotsLimit, "Too much era shots");

    //     // checks if _user haven't shots in era yet
    //     if (usersShotsPerEra[_user][era].length == 0) {
    //         uint[] memory arr = usersShotsPerEra[_user][era - 1];

    //         if (arr.length > 0) {
    //             uint256 _amount = findMedian(arr);

    //             Staker storage staker = dapps["AdaptersUtility"].stakers[_user];    
    //             staker.eraBalance[era] += _amount;

    //             if (staker.eraBalance[era] == 0) {
    //                 staker.isZeroBalance[era] = true;
    //             } else {
    //                 staker.isZeroBalance[era] = false;
    //             }   
                
    //             if (dapps["AdaptersUtility"].stakers[_user].lastClaimedEra == 0) {
    //                 dapps["AdaptersUtility"].stakers[_user].lastClaimedEra = era;
    //             }
    //         }
    //     }

    //     uint lpBal = getUserLpTokens(_user);
    //     usersShotsPerEra[_user][era].push(lpBal);
    // }

    // --------------------------------------------------------------------
    // Migration // Function to migrate values from buffer ----------------
    // --------------------------------------------------------------------

    // /// @notice function for migrating users storage
    // /// @param _user => user address
    // /// @dev the beginning of the migration must be carried out at the beginning of a new era
    // /// @dev before starting the migration, you must first call eraShot 
    // ///      for each user to calculate his rewards for the past era
    // /// @dev before starting the migration, you need to make a claim of 
    // ///      rewards for all past eras and call the sync function for all non-updated eras
    // function migrateStorage(address _user) public onlyRole(MANAGER) {
    //     if (_user == address(0)) return;

    //     uint256 _era = currentEra();
    //     dapps[utilName].stakers[_user].rewards = totalUserRewards[_user];
    //     dapps[utilName].stakers[_user].eraBalance[_era] = distr.getUserDntBalanceInUtil(_user, utilName, DNTname) - buffer[_user][_era];
    //     dapps[utilName].stakers[_user].isZeroBalance[_era] = dapps[utilName].stakers[_user].eraBalance[_era] == 0 ? true : false;
    //     dapps[utilName].stakers[_user].eraBalance[_era + 1] = distr.getUserDntBalanceInUtil(_user, utilName, DNTname) - buffer[_user][_era + 1];
    //     dapps[utilName].stakers[_user].isZeroBalance[_era + 1] = dapps[utilName].stakers[_user].eraBalance[_era = 1] == 0 ? true : false;
    //     dapps[utilName].stakers[_user].lastClaimedEra = _era;
    // }

    // --------------------------------------------------------------------
    // Mock functions // Functions for tests only -------------------------
    // --------------------------------------------------------------------

    /// @notice function for tests
    function setting() external {
        DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance);
    }
}   
