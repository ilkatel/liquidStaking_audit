//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ISiriusFarm.sol";
import "./interfaces/ISiriusPool.sol";
import "./interfaces/IMinter.sol";
import "./interfaces/IPancakePair.sol";

contract SiriusAdapter is OwnableUpgradeable, ReentrancyGuard {

    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;
    using SafeERC20 for IERC20;
    using SafeERC20 for IPancakePair;

    uint8 private idxNtoken;
    uint8 private idxToken;

    uint256 public accumulatedRewardsPerShare;
    uint256 public revenuePool;
    uint256 private constant REWARDS_PRECISION = 1e12; // A big number to perform mul and div operations
    uint256 public constant REVENUE_FEE = 10; // 10% of claimed rewards goes to revenue pool

    address public token;

    mapping(address => uint256) public lpBalances;
    mapping(address => uint256) public gaugeBalances;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public rewardDebt;

    bool private abilityToAddLpAndGauge;

    ISiriusPool public pool;
    ISiriusFarm public farm;
    IPancakePair public pair;
    IERC20 public lp;
    IERC20 public nToken;
    IERC20 public gauge;
    IERC20 public srs;
    IMinter public minter;

    event AddLiquidity(address indexed user, uint256[] indexed amounts, bool autoStake, uint256 indexed lpAmount);
    event RemoveLiquidity(address indexed user, uint256 amountLP, uint256 indexed receivedASTR);
    event DepositLP(address indexed, uint256 amount);
    event WithdrawLP(address indexed user, uint256 indexed amount, bool indexed autoWithdraw);
    event Claim(address indexed user, uint256 indexed amount);
    event HarvestRewards(address indexed user, uint256 indexed rewardsToHarvest);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        ISiriusPool _pool,
        ISiriusFarm _farm,
        IPancakePair _pair,
        IERC20 _lp,
        IERC20 _nToken,
        IERC20 _gauge,
        IERC20 _srs,
        IMinter _minter,
        address _token
    ) public initializer {
        __Ownable_init();
        pool = _pool;
        farm = _farm;
        lp = _lp;
        pair = _pair;
        nToken = _nToken;
        gauge = _gauge;
        srs = _srs;
        token = _token;
        minter = _minter;
        idxNtoken = pool.getTokenIndex(address(nToken));
        idxToken = pool.getTokenIndex(token);
        approves();
    }

    // @notice Updates rewards
    modifier update() {
        // check if there are unclaimed rewards
        uint256 unclaimedRewards = farm.claimableTokens(address(this));
        if (unclaimedRewards > 0) {
            harvestRewards();
        }
        _;
    }

    // @notice check if the caller is an external owned account
    modifier notAllowContract() {
        require(!msg.sender.isContract() && tx.origin == msg.sender, "Allows only for EOA");
        _;
    }

    // @notice To receive funds from pool contrct
    receive() external payable {}

    // @notice It is not supposed that funds will be accumulated on the contract
    //         This reserve function is needed to withdraw stucked funds
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // @notice Withdraw revenue part
    // @param _amount Amount of funds to withdraw
    function withdrawRevenue(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Not enough revenue");
        revenuePool -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // @notice After the transition of all users to adapters
    //         addLp() and addGauge() will be disabled by this function
    // @param _b enable or disable functionality
    function setAbilityToAddLpAndGauge(bool _b) external onlyOwner {
        abilityToAddLpAndGauge = _b;
    }

    // @notice approves tokens for pool and farm contracts
    function approves() private {
        nToken.safeApprove(address(pool), type(uint256).max);
        lp.safeApprove(address(pool), type(uint256).max);
        lp.safeApprove(address(farm), type(uint256).max);
        gauge.safeApprove(address(farm), type(uint256).max);
    }

    // @notice Add liquidity to the pool with the given amounts of tokens
    // @param _amounts The amounts of each token to add
    //        idx 0 is ASTR, idx 1 is nASTR
    // @param _autoStake If true, LP tokens go to stake at the same tx
    function addLiquidity(uint256[] calldata _amounts, bool _autoStake) external payable notAllowContract nonReentrant {
        require(msg.value == _amounts[0], "Value need to be equal to amount of ASTR tokens");
        require(_amounts[0] > 0 && _amounts[1] > 0, "Amounts of tokens should be greater than zero");

        nToken.safeTransferFrom(msg.sender, address(this), _amounts[1]);

        uint256 calculatedLpAmount = pool.calculateTokenAmount(_amounts, true);
        uint256 minToMint = calculatedLpAmount * 9 / 10; // min amount for slippage control

        uint256 lpAmount = pool.addLiquidity{value: msg.value}(_amounts, minToMint, block.timestamp + 1200);
        lpBalances[msg.sender] += lpAmount;

        if (_autoStake) {
            depositLP(lpAmount);
        }
        emit AddLiquidity(msg.sender, _amounts, _autoStake, lpAmount);
    }

    // @notice Remove liquidity from the pool
    // @param _amounts Amount of LP tokens to remove
    function removeLiquidity(uint256 _amount) public notAllowContract {
        require(_amount > 0, "Should be greater than zero");
        require(lpBalances[msg.sender] >= _amount, "Not enough LP");

        uint256[] memory minAmounts = new uint256[](2);
        minAmounts = pool.calculateRemoveLiquidity(_amount);

        uint256 beforeTokens = address(this).balance;
        uint256 beforeNtokens = nToken.balanceOf(address(this));
        pool.removeLiquidity(_amount, minAmounts, block.timestamp + 1200);
        uint256 afterTokens = address(this).balance;
        uint256 afterNtokens = nToken.balanceOf(address(this));

        uint256 receivedNtokens = afterNtokens - beforeNtokens;
        uint256 receivedTokens = afterTokens - beforeTokens;

        lpBalances[msg.sender] -= _amount;

        nToken.safeTransfer(msg.sender, receivedNtokens);
        payable(msg.sender).sendValue(receivedTokens);
        emit RemoveLiquidity(msg.sender, _amount, receivedTokens);
    }

    // @notice With this function users can transfer LP tokens to their balance in the adapter contract
    //         Needed to move from "handler contracts" to adapters
    // @param _autoDeposit Allows to deposit LP at the same tx
    function addLp(bool _autoDeposit) external notAllowContract nonReentrant {
        require(!abilityToAddLpAndGauge, "Functionality disabled");
        uint256 amount = lp.balanceOf(msg.sender);
        lp.safeTransferFrom(msg.sender, address(this), amount);
        lpBalances[msg.sender] += amount;

        if (_autoDeposit) {
            depositLP(amount);
        }
    }

    // @notice Receive Gauge tokens from user
    function addGauge() external notAllowContract nonReentrant {
        require(!abilityToAddLpAndGauge, "Functionality disabled");
        uint256 amount = gauge.balanceOf(msg.sender);
        gauge.safeTransferFrom(msg.sender, address(this), amount);
        gaugeBalances[msg.sender] += amount;

        // from this moment user can pretend to rewards so set him rewardDebt
        rewardDebt[msg.sender] = gaugeBalances[msg.sender] * accumulatedRewardsPerShare / REWARDS_PRECISION;
    }

    // @notice Deposit LP tokens to farm pool and receives Gauge tokens instead
    // @param _amount Amount of LP tokens
    function depositLP(uint256 _amount) public update notAllowContract {
        require(lpBalances[msg.sender] >= _amount, "Not enough LP tokens");
        require(_amount > 0, "Shoud be greater than zero");

        lpBalances[msg.sender] -= _amount;

        uint256 beforeGauge = gauge.balanceOf(address(this));
        farm.deposit(_amount, address(this), false);
        uint256 afterGauge = gauge.balanceOf(address(this));
        uint256 receivedGauge = afterGauge - beforeGauge;

        gaugeBalances[msg.sender] += receivedGauge;
        rewardDebt[msg.sender] = gaugeBalances[msg.sender] * accumulatedRewardsPerShare / REWARDS_PRECISION;
        emit DepositLP(msg.sender, _amount);
    }

    // @notice Receives LP tokens back instead of Gauge
    // @param _amount Amount of Gauge tokens
    // @param _autoWithdraw If true remove all liquidity at the same tx
    function withdrawLP(uint256 _amount, bool _autoWithdraw) external update notAllowContract {
        require(gaugeBalances[msg.sender] >= _amount, "Not enough Gauge tokens");
        require(_amount > 0, "Shoud be greater than zero");

        rewardDebt[msg.sender] = gaugeBalances[msg.sender] * accumulatedRewardsPerShare / REWARDS_PRECISION;

        uint256 balBefore = lp.balanceOf(address(this));
        farm.withdraw(_amount, false);
        uint256 balAfter = lp.balanceOf(address(this));
        uint256 receivedAmount = balAfter - balBefore;

        gaugeBalances[msg.sender] -= _amount;
        lpBalances[msg.sender] += receivedAmount;

        if (_autoWithdraw) {
            uint256 userLpBalance = lpBalances[msg.sender];
            removeLiquidity(userLpBalance);
        }
        emit WithdrawLP(msg.sender, _amount, _autoWithdraw);
    }

    // @notice Collect all rewards by user
    function harvestRewards() private {
        // updates accumulatedRewardsPerShare
        updatePoolRewards();

        uint256 stakedAmount = gaugeBalances[msg.sender];

        // calculates the user's share of the total number of awards and subtracts from it accumulated rewardDebt
        uint256 rewardsToHarvest = (stakedAmount * accumulatedRewardsPerShare / REWARDS_PRECISION) - rewardDebt[msg.sender];

        rewardDebt[msg.sender] = stakedAmount * accumulatedRewardsPerShare / REWARDS_PRECISION;

        // collect user rewards that can be claimed
        rewards[msg.sender] += rewardsToHarvest;

        emit HarvestRewards(msg.sender, rewardsToHarvest);
    }

    // @notice Receives portion of total rewards in SRS tokens from the farm contract
    function updatePoolRewards() private {
        uint256 balBefore = srs.balanceOf(address(this));
        minter.mint(address(gauge));
        uint256 balAfter = srs.balanceOf(address(this));
        uint256 receivedRewards = balAfter - balBefore;

        uint256 totalStaked = gauge.balanceOf(address(this)); // get total amount of staked LP tokens
        if (totalStaked == 0) return;

        // increases accumulated rewards per 1 staked token
        accumulatedRewardsPerShare += receivedRewards * REWARDS_PRECISION / totalStaked;
    }

    // @notice For claim rewards by users
    function claim() external update notAllowContract{
        require(rewards[msg.sender] > 0, "User has no any rewards");
        uint256 comissionPart = rewards[msg.sender] / REVENUE_FEE; // 10% comission part which go to revenue pool
        uint256 rewardsToClaim = rewards[msg.sender] - comissionPart;
        revenuePool += comissionPart;
        rewards[msg.sender] = 0;
        srs.safeTransfer(msg.sender, rewardsToClaim);
        emit Claim(msg.sender, rewardsToClaim);
    }

    // @notice Get share of n tokens in pool for user
    // @param _user User's address
    function calc(address _user) external view returns (uint256 nShare) {
        uint256 virtualPrice = pool.getVirtualPrice() / 10**18;
        uint256 nTokensInPool = pool.getTokenBalance(idxNtoken);
        uint256 tokensInPool = pool.getTokenBalance(idxToken);
        nShare = ((lpBalances[_user] + gaugeBalances[_user]) * virtualPrice) * nTokensInPool / (tokensInPool + nTokensInPool);
    }
}
