//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/ISiriusFarm.sol";
import "./interfaces/ISiriusPool.sol";
import "./interfaces/IDNT.sol";

contract SiriusAdapter is OwnableUpgradeable {

    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;

    uint8 private idxNtoken;
    uint8 private idxToken;

    uint256 public accumulatedRewardsPerShare;
    uint256 private constant REWARDS_PRECISION = 1e12; // A big number to perform mul and div operations

    address public token;

    mapping(address => uint256) public lpBalances;
    mapping(address => uint256) public gaugeBalances;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public rewardDebt;

    bool private abilityToAddLpAndGauge;

    ISiriusPool public pool;
    ISiriusFarm public farm;
    IDNT public lp;
    IDNT public nToken;
    IDNT public gauge;
    IDNT public srs;

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
        IDNT _lp,
        IDNT _nToken,
        IDNT _gauge,
        IDNT _srs,
        address _token
    ) public initializer {
        __Ownable_init();
        pool = _pool;
        farm = _farm;
        lp = _lp;
        nToken = _nToken;
        gauge = _gauge;
        srs = _srs;
        token = _token;
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

    // @notice To receive funds from pool contrct
    receive() external payable {}

    // @notice It is not supposed that funds will be accumulated on the contract
    //         This reserve function is needed to withdraw stucked funds
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // @notice After the transition of all users to adapters
    //         addLp() and addGauge() will be disabled by this function
    // @param _b enable or disable functionality
    function setAbilityToAddLpAndGauge(bool _b) external onlyOwner {
        abilityToAddLpAndGauge = _b;
    }

    // @notice approves tokens for pool and farm contracts
    function approves() private {
        require(nToken.approve(address(pool), type(uint256).max), "nToken approve error");
        require(lp.approve(address(pool), type(uint256).max), "LP approve error");
        require(lp.approve(address(farm), type(uint256).max), "LP approve error");
        require(gauge.approve(address(farm), type(uint256).max), "Gauge approve error");
    }

    // @notice Add liquidity to the pool with the given amounts of tokens
    // @param _amounts The amounts of each token to add
    //        idx 0 is ASTR, idx 1 is nASTR
    // @param _autoStake If true, LP tokens go to stake at the same tx
    function addLiquidity(uint256[] calldata _amounts, bool _autoStake) external payable update {
        require(!(msg.sender.isContract()), "Allows only for external owned accounts");
        require(msg.value == _amounts[0], "Wrong value");
        require(_amounts[0] > 0 && _amounts[1] > 0, "Amounts of tokens should be greater than zero");

        require(nToken.transferFrom(msg.sender, address(this), msg.value), "Error while nASTR transfer");

        uint256 lpAmount = pool.addLiquidity{value: msg.value}(_amounts, 0, block.timestamp + 1200);
        lpBalances[msg.sender] += lpAmount;

        if (_autoStake) {
            depositLP(lpAmount);
        }
        emit AddLiquidity(msg.sender, _amounts, _autoStake, lpAmount);
    }

    // @notice Remove liquidity from the pool
    // @param _amounts Amount of LP tokens to remove
    function removeLiquidity(uint256 _amount) public update {
        require(_amount > 0, "Should be greater than zero");
        require(lpBalances[msg.sender] >= _amount, "Not enough LP");
        require(!(msg.sender.isContract()), "Allows only for external owned accounts");

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

        require(nToken.transfer(msg.sender, receivedNtokens), "Error while nASTR transfer");
        payable(msg.sender).sendValue(receivedTokens);
        emit RemoveLiquidity(msg.sender, _amount, receivedTokens);
    }

    // @notice With this function users can transfer LP tokens to their balance in the adapter contract
    //         Needed to move from "handler contracts" to adapters
    // @param _autoDeposit Allows to deposit LP at the same tx
    function addLp(bool _autoDeposit) external {
        require(!abilityToAddLpAndGauge, "Functionality disabled");
        require(!(msg.sender.isContract()), "Allows only for external owned accounts");
        uint256 amount = lp.balanceOf(msg.sender);
        require(amount > 0, "LP tokens not found");
        require(lp.transferFrom(msg.sender, address(this), amount), "Error while LP tokens receiving");
        lpBalances[msg.sender] += amount;

        if (_autoDeposit) {
            depositLP(amount);
        }
    }

    // @notice Receive Gauge tokens from user
    function addGauge() external {
        require(!abilityToAddLpAndGauge, "Functionality disabled");
        require(!(msg.sender.isContract()), "Allows only for external owned accounts");
        uint256 amount = gauge.balanceOf(msg.sender);
        require(amount > 0, "Gauge tokens not found");
        require(gauge.transferFrom(msg.sender, address(this), amount), "Error while Gauge tokens receiving");
        gaugeBalances[msg.sender] += amount;

        // from this moment user can pretend to rewards so set him rewardDebt
        rewardDebt[msg.sender] = amount * accumulatedRewardsPerShare / REWARDS_PRECISION;
    }

    // @notice Deposit LP tokens to farm pool and receives Gauge tokens instead
    // @param _amount Amount of LP tokens
    function depositLP(uint256 _amount) public update {
        require(lpBalances[msg.sender] >= _amount, "Not enough LP tokens");
        require(_amount > 0, "Shoud be greater than zero");
        require(!(msg.sender.isContract()), "Allows only for external owned accounts");

        lpBalances[msg.sender] -= _amount;

        uint256 beforeGauge = gauge.balanceOf(address(this));
        farm.deposit(_amount, address(this), false);
        uint256 afterGauge = gauge.balanceOf(address(this));
        uint256 receivedGauge = afterGauge - beforeGauge;

        gaugeBalances[msg.sender] += receivedGauge;
        rewardDebt[msg.sender] = _amount * accumulatedRewardsPerShare / REWARDS_PRECISION;
        emit DepositLP(msg.sender, _amount);
    }

    // @notice Receives LP tokens back instead of Gauge
    // @param _amount Amount of Gauge tokens
    // @param _autoWithdraw If true remove all liquidity at the same tx
    function withdrawLP(uint256 _amount, bool _autoWithdraw) external update {
        require(gaugeBalances[msg.sender] >= _amount, "Not enough Gauge tokens");
        require(_amount > 0, "Shoud be greater than zero");
        require(!(msg.sender.isContract()), "Allows only for external owned accounts");

        rewardDebt[msg.sender] = _amount * accumulatedRewardsPerShare / REWARDS_PRECISION;

        uint256 balBefore = lp.balanceOf(address(this));
        farm.withdraw(_amount, false);
        uint256 balAfter = lp.balanceOf(address(this));
        uint256 receivedAmount = balAfter - balBefore;

        gaugeBalances[msg.sender] -= receivedAmount;
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

        if (rewardsToHarvest == 0) {
            rewardDebt[msg.sender] = stakedAmount * accumulatedRewardsPerShare / REWARDS_PRECISION;
            return;
        }

        rewardDebt[msg.sender] = stakedAmount * accumulatedRewardsPerShare / REWARDS_PRECISION;

        // collect user rewards that can be claimed
        rewards[msg.sender] += rewardsToHarvest;

        emit HarvestRewards(msg.sender, rewardsToHarvest);
    }

    // @notice Receives portion of total rewards in SRS tokens from the farm contract
    function updatePoolRewards() private {
        uint256 balBefore = srs.balanceOf(address(this));
        farm.claimRewards(address(this), address(0)); // address(0) says that the dirrection of the rewards will be default
        uint256 balAfter = srs.balanceOf(address(this));
        uint256 receivedRewards = balAfter - balBefore;

        uint256 totalStaked = gauge.balanceOf(address(this)); // get total amount of staked LP tokens
        if (totalStaked == 0) return;

        // increases accumulated rewards per 1 staked token
        accumulatedRewardsPerShare += receivedRewards * REWARDS_PRECISION / totalStaked;
    }

    // @notice For claim rewards by users
    function claim() external {
        require(rewards[msg.sender] > 0, "User has no any rewards");
        require(!msg.sender.isContract(), "Allows only for external owned accounts");
        rewards[msg.sender] = 0;
        require(srs.transfer(msg.sender, rewards[msg.sender]), "Error while transfer SRS");
        emit Claim(msg.sender, rewards[msg.sender]);
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
