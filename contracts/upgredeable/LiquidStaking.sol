//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/DappsStaking.sol";
import "./NDistributor.sol";
// import "./interfaces/NDistributor.sol";
import "./interfaces/IDNT.sol";
import "./interfaces/IPartnerHandler.sol"; /* 1 -> 1.5 will removed with next proxy update */
import "./interfaces/INFTDistributor.sol";
import "./interfaces/IAdaptersDistributor.sol";
import "./interfaces/INDistributor.sol";

/* @notice Liquid staking implementation contract
 *
 * https://docs.algem.io/algem-protocol/liquid-staking
 *
 * Features:
 * - Initializable
 * - AccessControlUpgradeable
 */
contract LiquidStaking is AccessControlUpgradeable {
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

    /* unused and will removed with next proxy update */struct Stake { 
    /* unused and will removed with next proxy update */    uint totalBalance;
    /* unused and will removed with next proxy update */    uint eraStarted;
    /* unused and will removed with next proxy update */}
    /* unused and will removed with next proxy update */mapping(address => Stake) public stakes;

    // @notice user requested withdrawals
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
    address public dntToken;
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
        // string dnt;
        uint256 stakedBalance;
        uint256 sum2unstake;
        mapping(address => Staker) stakers;
    }

    struct Staker {
        // era => era balance
        mapping(uint256 => uint256) eraBalance;
        // era => is zero balance
        mapping(uint256 => bool) isZeroBalance;

        mapping(uint256 => uint256) eraBonus;
        mapping(uint256 => bool) isZeroBonus;

        uint256 rewards;
        uint256 lastClaimedEra;
    }
    uint256 public lastEraTotalBalance;

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
    INDistributor public newDistr;

    event Staked(address indexed user, uint val);
    event StakedInUtility(address indexed user, string indexed utility, uint val);
    event Unstaked(address indexed user, uint amount, bool immediate);
    event UnstakedFromUtility(address indexed user, string indexed utility, uint amount, bool immediate);
    event Withdrawn(address indexed user, uint val);
    event Claimed(address indexed user, uint amount);
    event ClaimedFromUtility(address indexed user, string indexed utility, uint amount);

    event HarvestRewards(address indexed user, string indexed utility, uint amount);

    // events for events handle
    event ClaimStakerError(string indexed utility, uint indexed era);
    event UnbondAndUnstakeError(string indexed utility, uint sum2unstake, uint indexed era, bytes indexed reason);
    event WithdrawUnbondedError(uint indexed _era, bytes indexed reason);
    event ClaimDappError(uint indexed amount, uint indexed era, bytes indexed reason);

    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;


    // 
    // constructor() {
    //     _disableInitializers();
    // }  

    // ------------------ INIT
    // -----------------------
    function initialize() public initializer {
        // nftDistr = INFTDistributor(_nftDistr);
        // adaptersDistr = IAdaptersDistributor(_adaptersDistr);

        // _grantRole(MANAGER, _nftDistr);
        // _grantRole(MANAGER, _adaptersDistr);

        // dappsList.push(utilName);
        // haveUtility[utilName] = true;
        // isActive[utilName] = true;
        // dapps[utilName].dappAddress = address(this);
        // // dapps[utilName].dnt = DNTname;

        // dapps[utilName].sum2unstake = sum2unstake;
        // dapps[utilName].stakedBalance = distr.totalDntInUtil(utilName); 
        // // lastEraTotalBalance = distr.totalDnt(DNTname);
        // lastEraTotalBalance = 19987657;
    }

    function initialize2(address _nftDistr, address _adaptersDistr) external {
        newDistr = INDistributor(address(distr));
        nftDistr = INFTDistributor(_nftDistr);
        adaptersDistr = IAdaptersDistributor(_adaptersDistr);

        _grantRole(MANAGER, _nftDistr);
        _grantRole(MANAGER, _adaptersDistr);

        dappsList.push(utilName);
        haveUtility[utilName] = true;
        isActive[utilName] = true;
        dapps[utilName].dappAddress = address(this);
        // dapps[utilName].dnt = DNTname;

        dapps[utilName].sum2unstake = sum2unstake;
        dapps[utilName].stakedBalance = newDistr.totalDntInUtil(utilName); 
        lastEraTotalBalance = newDistr.totalDnt(DNTname);
    }

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

    // ----------------------

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
        require(msg.sender == address(newDistr) || msg.sender == address(adaptersDistr), "Only for distributor!");
        _;
    }

    /// @notice updates user rewards
    modifier updateRewards(address _user, string[] memory _utilities) {
        uint256 l =_utilities.length;

        // harvest rewards for current balances
        for (uint256 i; i < l; i++)
            harvestRewards(_utilities[i], _user);
        _;
        // update balances in utils
        for (uint256 i; i < l; i++)
            _updateUserBalanceInUtility(_utilities[i], _user);
    }

    /// @notice updates global balances
    modifier updateAll() {
        uint256 _era = currentEra();
        if (lastUpdated != _era) {
            updates(_era);
        }
        _;
    }

    /// @notice global updates function
    /// @param _era => era to update
    function updates(uint256 _era) private {
        globalWithdraw(_era);
        claimFromDapps(_era);
        claimDapp(_era);
        globalUnstake(_era);
        lastUpdated = _era;
    }

    /// @notice add new partner dapp
    /// @param _utility => dapp utility name
    /// @param _dapp => dapp address
    function addDapp(string memory _utility, address _dapp) external onlyRole(MANAGER) {
        require(_dapp != address(0), "Incorrect dapp address");
        require(!haveUtility[_utility], "Utility already added");

        newDistr.addUtility(_utility);
        dappsList.push(_utility);
        haveUtility[_utility] = true;
        isActive[_utility] = true;
        dapps[_utility].dappAddress = _dapp;
        // set default DNT (nASTR)
        // dapps[_utility].dnt = DNTname;
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

    // USER FUNCS -------------------------------------------------------

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

        if (!isStaker[msg.sender]) {
            isStaker[msg.sender] = true;
            stakers.push(msg.sender);
        }

        totalBalance += _stakeAmount;
        totalRevenue += value - _stakeAmount;

        uint256 _era = currentEra() + 1;

        for (uint256 i; i < l; i++) {
            if (dapps[_utilities[i]].stakers[msg.sender].lastClaimedEra == 0)
                dapps[_utilities[i]].stakers[msg.sender].lastClaimedEra = _era;

            if (_amounts[i] > 0) {
                string memory _utility = _utilities[i];

                DAPPS_STAKING.bond_and_stake(dapps[_utility].dappAddress, uint128(_amounts[i]));
                newDistr.issueDnt(msg.sender, _amounts[i], _utility, DNTname);

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
        uint256 era = currentEra(); 
        uint256 l = _utilities.length;
        uint256 totalUnstaked;

        for (uint256 i; i < l; i++) {
            require(haveUtility[_utilities[i]], "Unknown utility");
            if (_amounts[i] > 0) {
                string memory _utility = _utilities[i];
                uint256 _amount = _amounts[i];

                uint256 userDntBalance = newDistr.getUserDntBalanceInUtil(
                    msg.sender,
                    _utility,
                    DNTname
                );

                require(userDntBalance >= _amount, "Not enough nASTR in utility");
                Dapp storage dapp = dapps[_utility];

                dapp.sum2unstake += _amount;
                totalBalance -= _amount;
                dapp.stakedBalance -= _amount;

                newDistr.removeDnt(msg.sender, _amount, _utility, DNTname);

                if (_immediate) {
                    // get liquidity from unstaking pool
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
        if (totalUnstaked > 0) emit Unstaked(msg.sender, totalUnstaked, _immediate);
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
        string[] memory _utilities = newDistr.listUserUtilitiesInDnt(msg.sender, DNTname);

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

    // -----------------------------

    /// @notice harvest user rewards
    /// @param _utility => utility to harvest
    /// @param _user => user address
    function harvestRewards(string memory _utility, address _user) private {
        // calculate unclaimed user rewards
        (uint256 rewardsToHarvest, uint256 lastUserBalance) = calcUserRewards(_utility, _user);
        nftDistr.updateUser(_utility, _user, lastUpdated, lastUserBalance);
        dapps[_utility].stakers[_user].lastClaimedEra = lastUpdated;

        if (rewardsToHarvest == 0) return;

        // update user rewards
        dapps[_utility].stakers[_user].rewards += rewardsToHarvest;
        totalUserRewards[_user] += rewardsToHarvest;
        emit HarvestRewards(_user, _utility, rewardsToHarvest);
    }

    /// @notice clculate unclaimed user rewards from utility
    /// @param _utility => utility
    /// @param _user => user address
    /// @return userRewards => unclaimed user rewards from utility
    function calcUserRewards(string memory _utility, address _user) private view returns (uint256, uint256) {
        Staker storage user = dapps[_utility].stakers[_user];
        uint256 claimedEra = user.lastClaimedEra;
        uint256 _era = lastUpdated;

        (uint256 uB, ) = nftDistr.getUserEraBalance(_utility, _user, claimedEra);

        if (claimedEra >= _era || claimedEra < 1) return (0, uB);
    
        uint256 userRewards;
        uint256 userEraBalance = user.eraBalance[claimedEra];

        for (uint256 i = claimedEra; i < _era; ) {
            if (userEraBalance > 0) {
                uint256 userEraRewards = (userEraBalance * accumulatedRewardsPerShare[i] / REWARDS_PRECISION);

                if (uB > 0) {
                    uint8 userComission = nftDistr.getUserComission(_utility, _user);
                    userEraRewards = userEraRewards * (100 - userComission - UNSTAKING_FEE) / (100 - MANAGEMENT_FEE);
                }
                userRewards += userEraRewards;
            }
            
            if (user.eraBalance[i + 1] == 0) {
                // check isZeroBalance and set 0 if true
                // else userEraBalance[nextEra] = userEraBalance[currentEra]
                if (user.isZeroBalance[i + 1]) {
                    userEraBalance = 0;
                }
            } else {
                userEraBalance = user.eraBalance[i + 1];
            }

            (uint256 _uB, bool _zB) = nftDistr.getUserEraBalance(_utility, _user, i + 1);
            if (_uB == 0) {
                if (_zB) {
                    uB = 0;
                }
            } else {
                uB = _uB;
            }
            unchecked { ++i; }
        }
        return (userRewards, uB);
    }

    /// @notice preview all eser rewards from utility at current era
    /// @param _utility => utility
    /// @param _user => user address
    /// @return userRewards => unclaimed user rewards from utility
    function previewUserRewards(string memory _utility, address _user) external view returns (uint256) {
        (uint256 _userRew, ) = calcUserRewards(_utility, _user);
        return _userRew + dapps[_utility].stakers[_user].rewards;
    }

    // ------------------------------

    /// @notice claim staker rewards from all dapps
    /// @param _era => latest era to claim
    function claimFromDapps(uint256 _era) private {
        uint256 _lastUpd = lastUpdated;
        if (_lastUpd >= _era) return;  

        uint256 balanceBefore = address(this).balance;

        uint256 l = dappsList.length;
        for (uint256 i; i < l; i++) {
            _claimFromDapp(dappsList[i], _lastUpd, _era);
        }
        
        uint256 balanceAfter = address(this).balance;

        uint256 receivedRewards = balanceAfter - balanceBefore;

        uint256[2] memory erasData = nftDistr.getErasData(_lastUpd, _era);
        // uint256[2] memory erasData;
        // erasData[0] = 10000;
        // erasData[1] = 190;
        uint256 allErasBalance = lastEraTotalBalance * (_era - _lastUpd);

        uint256 rewardsK = receivedRewards * REWARDS_PRECISION / allErasBalance;
        uint256 nftRevenue = rewardsK * erasData[1] / (100 * REWARDS_PRECISION);
        uint256 defaultRevenue = rewardsK * REVENUE_FEE * (allErasBalance - erasData[0]) / (100 * REWARDS_PRECISION);
        uint256 toUnstaking = receivedRewards / 100;

        uint256 totalReceived = receivedRewards - nftRevenue - defaultRevenue - toUnstaking;

        totalRevenue += nftRevenue + defaultRevenue; // 9% of era reward s goes to revenue pool
        unstakingPool += toUnstaking; // 1% of era rewards goes to unstaking pool
        rewardPool += totalReceived;

        uint256 accRewPerShareByEra;
        if (lastEraTotalBalance > 0)
            accRewPerShareByEra = ((receivedRewards - receivedRewards / MANAGEMENT_FEE) * REWARDS_PRECISION / lastEraTotalBalance) / (_era - _lastUpd);

        // update accumulatedRewardsPerShare from all claimed now eras
        for (uint256 i = _lastUpd; i < _era; ) {
            accumulatedRewardsPerShare[i] = accRewPerShareByEra;
            unchecked { ++i; }
        }

        // update last era balance
        // last era balance = balance that participates in the current era
        lastEraTotalBalance = newDistr.totalDnt(DNTname);
    }   

    /// @notice claim staker rewards from utility
    /// @param _utility => utility
    /// @param _eraBegin => first era to claim
    /// @param _eraEnd => latest era to claim
    function _claimFromDapp(string memory _utility, uint256 _eraBegin, uint256 _eraEnd) private {
        // check active status
        uint256 eraEnd = isActive[_utility] ? _eraEnd : deactivationEra[_utility];
        for (_eraBegin; _eraBegin < eraEnd; ) {
            try DAPPS_STAKING.claim_staker(dapps[_utility].dappAddress) {}
            catch {
                emit ClaimStakerError(_utility, _eraBegin);
            }
            unchecked { ++_eraBegin; }
        }
    } 

    /// @notice claim dapp rewards for this contract
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

        try DAPPS_STAKING.withdraw_unbonded() {}
        catch (bytes memory reason) {
            emit WithdrawUnbondedError(_era, reason);
        }

        uint256 balanceAfter = address(this).balance;
        unbondedPool += balanceAfter - balanceBefore;
    }

    /// @notice ustake tokens from not yet updated eras from all dapps
    /// @param _era => latest era to update
    function globalUnstake(uint256 _era) private {
        if (_era * 10 < lastUnstaked * 10 + withdrawBlock * 10 / 4) {
            return;
        }

        uint256 l = dappsList.length;
        // unstake from all dapps
        for (uint256 i; i < l; i++) {
            _globalUnstake(dappsList[i], _era);
        }

        lastUnstaked = _era;
    }

    /// @notice ustake tokens from not yet updated eras from utility
    /// @param _utility => utility to unstake
    /// @param _era => latest era to update
    function _globalUnstake(string memory _utility, uint256 _era) private {
        Dapp storage dapp = dapps[_utility];

        if (dapp.sum2unstake == 0) return;

        if (!isActive[_utility]) {
            if (_era > deactivationEra[_utility]) return;
        }

        try DAPPS_STAKING.unbond_and_unstake(dapp.dappAddress, uint128(dapp.sum2unstake)) {
            dapp.sum2unstake = 0;
        } catch (bytes memory reason) {
            emit UnbondAndUnstakeError(_utility, dapp.sum2unstake, _era, reason);
        }
    }


    // ------------------------

    /// @notice update last user balance
    /// @param _utility => utility
    /// @param _user => user address
    function updateUserBalanceInUtility(string memory _utility, address _user) external onlyDistributor {
        _updateUserBalanceInUtility(_utility, _user);
    }

    function updateUserBalanceInAdapter(string memory _utility, address _user) external onlyDistributor {
        require(_user != address(0), "Zero address alarm!");
        uint256 _amount = adaptersDistr.getUserBalanceInAdapters(_user);
        _updateUserBalance(_utility, _user, _amount);
    }

    /// @notice update last user balance
    /// @param _utility => utility
    /// @param _user => user address
    function _updateUserBalanceInUtility(string memory _utility, address _user) private  {
        require(_user != address(0), "Zero address alarm!");
        // uint256 _amount = distr.getUserDntBalanceInUtil(_user, _utility, DNTname);
        uint256 _amount = 100;
        _updateUserBalance(_utility, _user, _amount);
    }

    function _updateUserBalance(string memory _utility, address _user, uint256 _amount) private {
        uint _era = currentEra() + 1;

        Staker storage staker = dapps[_utility].stakers[_user];

        if (dapps[_utility].stakers[_user].lastClaimedEra == 0)
            dapps[_utility].stakers[_user].lastClaimedEra = _era;

        // add to mapping
        if (_amount == 0) {
            staker.eraBalance[_era] = 0;
            staker.isZeroBalance[_era] = true;
            return;
        }

        staker.eraBalance[_era] = _amount;
        if (staker.isZeroBalance[_era]) {
            staker.isZeroBalance[_era] = false;
        }
    }

    /// @notice return users rewards
    /// @param _user => user address
    function getUserRewards(address _user) public view returns (uint) {
        return totalUserRewards[_user];
    }

    /// @notice return users rewards from utility
    /// @param _user => user address
    /// @param _utility => needful utility
    function getUserRewardsFromUtility(address _user, string memory _utility) public view returns (uint) {
        return dapps[_utility].stakers[_user].rewards;
    }

    // ------------------ VIEWS
    // ------------------------
    /// @notice get current era
    function currentEra() public view returns (uint) {
        return DAPPS_STAKING.read_current_era();
    }

    /// @notice return stakers array
    function getStakers() external view returns (address[] memory) {
        return stakers;
    }

    /// @notice returns user active withdrawals
    function getUserWithdrawals() external view returns (Withdrawal[] memory) {
        return withdrawals[msg.sender];
    }

    /// @notice sets min stake amount
    /// @param _amount => new min stake amount
    function setMinStakeAmount(uint _amount) public onlyRole(MANAGER) {
        minStakeAmount = _amount;
    }

    // ------------------ MISC
    // -----------------------

    /// @notice add new staker and save balances
    /// @param  _addr => user to add
    /// @param  _utility => user utility
    function addStaker(address _addr, string memory _utility) external onlyDistributor() {
        // require(!isStaker[_addr], "Already staker");
        if (!isStaker[msg.sender]) {
            stakers.push(_addr);
            isStaker[_addr] = true;
        }
        if (dapps[_utility].stakers[msg.sender].lastClaimedEra == 0)
            dapps[_utility].stakers[msg.sender].lastClaimedEra = currentEra() + 1;
    }

    /// @notice manually fill the unbonded pool
    function fillUnbonded() external payable {
        require(msg.value > 0, "Provide some value!");
        unbondedPool += msg.value;
    }

    /// @notice utility func for filling reward pool manually
    function fillRewardPool() external payable {
        require(msg.value > 0, "Provide some value!");
        rewardPool += msg.value;
    }

    /// @notice manually fill the unstaking pool
    function fillUnstaking() external payable {
        require(msg.value > 0, "Provide some value!");
        unstakingPool += msg.value;
    }

    /// @notice utility function in case of excess gas consumption
    function sync(uint _era) external onlyRole(MANAGER) {
        require(_era > lastUpdated && _era <= currentEra(), "Wrong era range");
        updates(_era);
    }
    
    /// @notice utility harvest function
    function syncHarvest(address _user, string[] memory _utilities) 
    external
    onlyRole(MANAGER)
    updateRewards(_user, _utilities) {}

    /// @notice withdraw revenu function
    function withdrawRevenue(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalRevenue >= _amount, "Not enough funds in revenue pool");
        totalRevenue -= _amount;
        payable(msg.sender).sendValue(_amount);
    }

    /// @notice disabled revoke ownership functionality
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
        _revokeRole(role, account);
    }

    /// @notice disabled revoke ownership functionality
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
    
    // ---------------------------------------------------------------
    // /* 1 -> 1.5 will removed with next proxy update */ // ---------
    // one week functions --------------------------------------------
    
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

    // MOCK ------------------------------
    /// @notice function for tests
    function setting() external {
        DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance);
    }

    /// @notice function for tests
    function getUserEraBalance(address _user, string memory _utility, uint256 _era) external view returns (uint256) {
        return dapps[_utility].stakers[_user].eraBalance[_era];
    }
}   