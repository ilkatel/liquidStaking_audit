//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IZenlinkRouter.sol";
import "./interfaces/IZenlinkFarm.sol";
import "./interfaces/IZenlinkPair.sol";

contract ZenlinkAdapter is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    //Interfaces
    IZenlinkFarm public farm;
    IZenlinkRouter public pool;
    IERC20Upgradeable public lp;
    IZenlinkPair public pair;
    IERC20Upgradeable public nToken;
    IERC20Upgradeable public zlkToken;

    uint256 public constant REVENUE_FEE = 10; // 10% of claimed rewards goes to revenue pool
    uint256 public constant SLIPPAGE_CONTROL = 8; // 0.8% of amounts to slippage control. Same values as in the Arthswap pool
    uint256 private constant REWARDS_PRECISION = 1e12; // A big number to perform mul and div operations
    uint256 private constant SLIPPAGE_PRECISION = 1000; // needed to get certain slippage percentage

    uint256 public accumulatedRewardsPerShare;
    uint256 public revenuePool;
    uint256 public totalStakedLp;
    uint256 private pid;

    mapping(address => uint256) public lpBalances;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public depositedLp;
    mapping(address => uint256) public rewardDebt;

    //Events
    event AddLiquidity(
        address indexed user,
        uint256 astrAmount,
        uint256 nastrAmount,
        bool indexed autoStake,
        uint256 indexed lpAmount
    );
    event RemoveLiquidity(
        address indexed user,
        uint256 amountLP,
        uint256 indexed receivedASTR
    );
    event DepositLP(address indexed, uint256 amount);
    event WithdrawLP(
        address indexed user,
        uint256 indexed amount,
        bool indexed autoWithdraw
    );
    event Claim(address indexed user, uint256 indexed amount);
    event HarvestRewards(
        address indexed user,
        uint256 indexed rewardsToHarvest
    );
    event NotClaimable();

    // @notice Updates rewards
    modifier update() {

        uint256 unclaimedRewards;
        (uint256[] memory rewardsArr, ) = farm.pendingRewards(pid, address(this));
        for (uint i; i < rewardsArr.length;) {
            unclaimedRewards += rewardsArr[i];
            unchecked { i++; }
        }

        // check if there are unclaimed rewards
        if (unclaimedRewards > 0) {
            updatePoolRewards();
        }

        harvestRewards();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IZenlinkFarm _farm,
        IZenlinkRouter _pool,
        IERC20Upgradeable _nToken,
        IERC20Upgradeable _lp,
        IZenlinkPair _pair,
        IERC20Upgradeable _zlkToken,
        uint256 _pid
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        farm = _farm;
        pool = _pool;
        lp = _lp;
        nToken = _nToken;
        pair = _pair;
        zlkToken = _zlkToken;
        pid = _pid;
    }

    // @notice To receive funds from pool contrct
    receive() external payable {
        require(msg.sender == address(pool), "Sending tokens not allowed");
    }

    // @notice Withdraw revenue part
    // @param _amount Amount of funds to withdraw
    function withdrawRevenue(uint256 _amount) external onlyOwner {
        require(
            zlkToken.balanceOf(address(this)) >= _amount,
            "Not enough ZLK revenue"
        );
        require(_amount > 0, "Should be greater than zero");
        revenuePool -= _amount;
        zlkToken.safeTransfer(msg.sender, _amount);
    }

    // @notice Add liquidity to the pool with the given amounts of tokens
    // @param _amounts The amounts of each token to add
    //        idx 0 is ASTR, idx 1 is nASTR
    // @param _autoStake If true, LP tokens go to stake at the same tx
    function addLiquidity(uint256[] calldata _amounts, bool _autoStake)
        external
        payable
        nonReentrant
    {
        require(
            msg.value == _amounts[0],
            "Value need to be equal to amount of ASTR tokens"
        );
        require(
            _amounts[1] > 0 && _amounts[0] > 0,
            "Amount of tokens should be greater than zero"
        );
        require(
            _amounts.length == 2,
            "The length of amounts must be equal to two"
        );

        nToken.safeTransferFrom(msg.sender, address(this), _amounts[1]);

        // vars for slippage control
        uint256 amountTokenMin = _amounts[1] -
            (_amounts[1] * SLIPPAGE_CONTROL) /
            SLIPPAGE_PRECISION;
        uint256 amountASTRMin = msg.value -
            (msg.value * SLIPPAGE_CONTROL) /
            SLIPPAGE_PRECISION;

        nToken.approve(address(pool), _amounts[1]);

        (,, uint256 receivedLP) = pool.addLiquidityNativeCurrency{value: msg.value}(
            address(nToken),
            _amounts[1],
            amountTokenMin,
            amountASTRMin,
            address(this),
            block.timestamp + 1200
        );

        lpBalances[msg.sender] += receivedLP;

        if (_autoStake) {
            depositLP(receivedLP);
        }

        emit AddLiquidity(
            msg.sender,
            msg.value,
            _amounts[1],
            _autoStake,
            receivedLP
        );
    }

    // @notice Remove liquidity from the pool
    // @param _amount Number of LP tokens ot remove
    function removeLiquidity(uint256 _amount)
        public
        nonReentrant
    {
        require(_amount > 0, "Should be greater than zero");
        require(lpBalances[msg.sender] >= _amount, "Not enough LP");

        uint256[] memory calculatedAmounts = calculateRemoveLiquidity(_amount);
        (uint256 astrPredicted, uint256 nastrPredicted) = (
            calculatedAmounts[0],
            calculatedAmounts[1]
        );

        uint256 amountNASTRmin = nastrPredicted -
            ((nastrPredicted * SLIPPAGE_CONTROL) / SLIPPAGE_PRECISION);
        uint256 amountASTRmin = astrPredicted -
            ((astrPredicted * SLIPPAGE_CONTROL) / SLIPPAGE_PRECISION);

        // allow the pool take the _amount of lp
        lp.approve(address(pool), _amount);

        (uint amountToken, uint amountASTR) = pool.removeLiquidityNativeCurrency(
            address(nToken),
            _amount,
            amountNASTRmin,
            amountASTRmin,
            address(this),
            block.timestamp + 1200
        );

        lpBalances[msg.sender] -= _amount;

        nToken.safeTransfer(msg.sender, amountToken);

        payable(msg.sender).sendValue(amountASTR); 

        emit RemoveLiquidity(msg.sender, amountToken, amountASTR);
    }

    // @notice With this function users can transfer
    //         LP tokens to their balance in the adapter contract
    // @param _autoDeposit Allows to deposit LP at the same tx
    function addLp(uint256 _amount, bool _autoDeposit)
        external
        nonReentrant
    {
        require(_amount > 0, "Should be greater than zero");
        require(
            _amount <= lp.balanceOf(msg.sender),
            "Not enough LP tokens on balance"
        );

        lp.safeTransferFrom(msg.sender, address(this), _amount);
        lpBalances[msg.sender] += _amount;

        if (_autoDeposit) {
            depositLP(_amount);
        }
    }

    // @notice Deposit LP tokens to ZLK allocation
    // @param _amount Number of LP tokens
    function depositLP(uint256 _amount) public update {
        require(lpBalances[msg.sender] >= _amount, "Not enough LP tokens");
        require(_amount > 0, "Should be greater than zero");

        lpBalances[msg.sender] -= _amount;

        // allow the farm take the _amount of lp
        lp.approve(address(farm), _amount);

        farm.stake(pid, address(lp), _amount);

        depositedLp[msg.sender] += _amount;
        totalStakedLp += _amount;

        rewardDebt[msg.sender] =
            (depositedLp[msg.sender] * accumulatedRewardsPerShare) /
            REWARDS_PRECISION;

        emit DepositLP(msg.sender, _amount);
    }

    // @notice Withdraw LP tokens from the pool
    // @param _amount Number of LP
    // @param _autoWithdraw Withdraw LP from farm and remove liquidity
    //                      at same transaction, if true
    function withdrawLP(uint256 _amount, bool _autoWithdraw)
        external
        update
    {
        require(
            depositedLp[msg.sender] >= _amount,
            "Not enough deposited LP tokens"
        );
        require(_amount > 0, "Should be greater than zero");

        depositedLp[msg.sender] -= _amount;
        totalStakedLp -= _amount;

        uint256 beforeLp = lp.balanceOf(address(this));
        farm.redeem(pid, address(lp), _amount);
        uint256 afterLp = lp.balanceOf(address(this));
        uint256 receivedLp = afterLp - beforeLp;

        lpBalances[msg.sender] += receivedLp;

        rewardDebt[msg.sender] = depositedLp[msg.sender] * accumulatedRewardsPerShare / REWARDS_PRECISION;

        if (_autoWithdraw) {
            removeLiquidity(_amount);
        }

        emit WithdrawLP(msg.sender, _amount, _autoWithdraw);
    }

    // @notice Collect all rewards by user
    function harvestRewards() private {
        uint256 stakedAmount = depositedLp[msg.sender];

        // calculates the user's share of the total number of awards and subtracts from it accumulated rewardDebt
        uint256 rewardsToHarvest = ((stakedAmount *
            accumulatedRewardsPerShare) / REWARDS_PRECISION) -
            rewardDebt[msg.sender];

        rewardDebt[msg.sender] =
            (stakedAmount * accumulatedRewardsPerShare) /
            REWARDS_PRECISION;

        // collect user rewards that can be claimed
        rewards[msg.sender] += rewardsToHarvest;

        emit HarvestRewards(msg.sender, rewardsToHarvest);
    }

    // @notice Receives portion of total rewards in ZLK tokens from the farm contract
    function updatePoolRewards() private {
        uint256 beforeZlk = zlkToken.balanceOf(address(this));
        try farm.claim(pid) {}
        catch {
            emit NotClaimable();
        }
        uint256 afterZlk = zlkToken.balanceOf(address(this));
        uint256 receivedRewards = afterZlk > beforeZlk
            ? afterZlk - beforeZlk
            : 0;

        if (totalStakedLp == 0) return;

        // increases accumulated rewards per 1 staked token
        accumulatedRewardsPerShare +=
            (receivedRewards * REWARDS_PRECISION) /
            totalStakedLp;
    }

    // @notice Convert LP tokens to nASTR/ASTR
    // @param _amount Number of LP tokens
    // @return Array of amounts
    //         _amounts[0] => ASTR amount
    //         _amounts[1] => nASTR amount
    function calculateRemoveLiquidity(uint256 _amount)
        public
        view
        returns (uint256[] memory)
    {
        (uint256 reservesNASTR, uint256 reservesASTR,) = pair.getReserves();
        uint256 totalLpSupply = lp.totalSupply();
        uint256 nastrAmount = (_amount * reservesNASTR) / totalLpSupply;
        uint256 astrAmount = (_amount * reservesASTR) / totalLpSupply;
        uint256[] memory amounts = new uint256[](2);
        (amounts[0], amounts[1]) = (astrAmount, nastrAmount);
        return amounts;
    }

    // @notice For claim rewards by users
    function claim() external update nonReentrant {
        require(rewards[msg.sender] > 0, "User has no any rewards");
        uint256 comissionPart = rewards[msg.sender] / REVENUE_FEE; // 10% comission part which go to revenue pool
        uint256 rewardsToClaim = rewards[msg.sender] - comissionPart;
        revenuePool += comissionPart;
        rewards[msg.sender] = 0;
        zlkToken.safeTransfer(msg.sender, rewardsToClaim);
        emit Claim(msg.sender, rewardsToClaim);
    }

    // @notice Needs to check user rewards
    // @param _user User address
    // @return sum Amount of penging rewards
    function pendingRewards(address _user) public view returns (uint256 sum) {
        uint256 stakedAmount = depositedLp[_user];
        if (stakedAmount > 0) {
            sum =
                rewards[_user] +
                (stakedAmount * accumulatedRewardsPerShare) /
                REWARDS_PRECISION -
                rewardDebt[_user];
        } else {
            sum = rewards[_user];
        }
    }

    // @notice Get share of n tokens in pool for user
    // @param _user User's address
    function calc(address _user) external view returns (uint256 nShare) {
        (, uint256 nTokensReserves,) = pair.getReserves();
        nShare =
            ((lpBalances[_user] + depositedLp[_user]) * nTokensReserves) /
            lp.totalSupply();
    }

    // @notice Disabled functionality to renounce ownership
    function renounceOwnership() public override onlyOwner {
        revert("It is not possible to renounce ownership at all");
    }

    // @notice Calculates amount of second token with the same value
    //         Helper function for front-end
    // @param _amount One of two tokens
    // @param _isAstr If amount of ASTR tokens specified above, then true
    // @return Equal value of second token
    function getSecondAmount(uint256 _amount, bool _isAstr)
        external
        view
        returns (uint256 sum)
    {   
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        sum = _isAstr
            ? _amount * reserve0 / reserve1
            : _amount * reserve1 / reserve0;
    }

    // @notice Technical function, that shadows depositedLp functionality
    //         Needed to using the same abi for all adapters
    // @return Amount of depoposited LP by user
    function gaugeBalances(address _user) public view returns (uint256) {
        return depositedLp[_user];
    }

    // @notice To get total amount of locked tokens in pool for front-end
    // @return Total amount of tokens in pool
    function totalReserves() public view returns (uint256 sum) {
        (uint256 astr, uint256 nastr,) = pair.getReserves();
        sum = nastr + astr;
    }

    // @notice Used for getting apr and tvl info
    // @param astrprice Actual rate ASTR to USD
    // @return tvl Total locked value
    // @return apr Annual Percentage Rate
    function getInfo(
        uint256 astrPrice
    ) public view returns (uint256 tvl, uint256 apr) {
        require(astrPrice > 0, "Zero address alarm");
        IZenlinkFarm chef = IZenlinkFarm(0x460ee9DBc82B2Be84ADE50629dDB09f6A1746545);
        IZenlinkPair zlkAstrPair = IZenlinkPair(0xba75fD35762e1dA55bc1893B3c0845BEee833d52);
        IZenlinkPair usdcAstrPair = IZenlinkPair(0x77fE816550d8FdD0Fcb0cdeA66541F3d76918681);
        uint256 PRICE_PRECISION = 10000;

        // get rewards per block for current pool
        (,,,uint256[] memory rewardsPerBlock,,,,) = chef.getPoolInfo(0);
        uint256 zlkPerBlock = rewardsPerBlock[0];

        // get zlk price
        (uint256 zlkRsrws, uint256 astrRsrws,) = zlkAstrPair.getReserves();
        uint256 zlkPrice = astrPrice * astrRsrws * PRICE_PRECISION / zlkRsrws;

        // get tvl
        (, uint256 astrReserves,) = usdcAstrPair.getReserves();
        tvl = astrReserves * 2 * astrPrice / 1e18;

        apr = (zlkPerBlock * (365 * 24 * 3600 / 12) * zlkPrice / 1e18 / PRICE_PRECISION + tvl) * 1e18 / tvl;
    }

    // @notice Used to calculate LP amount by giving nASTR and ASTR
    // @param _amounts Amounts of tokens. ASTR amount at idx 0
    // @return LP amount
    function getLpAmount(uint256[] memory _amounts) public view returns (uint256 amount) {
        (uint256 nastrRsrvs, uint256 astrRsrvs,) = pair.getReserves();
        uint256 totalSupply = lp.totalSupply();
        uint256 shareNastr = _amounts[1] * totalSupply / nastrRsrvs;
        uint256 shareAstr = _amounts[0] * totalSupply / astrRsrvs;
        return shareNastr < shareAstr ? shareNastr : shareAstr;
    }
}