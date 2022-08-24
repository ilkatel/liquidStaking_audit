//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ISiriusFarm.sol";
import "./interfaces/ISiriusPool.sol";
import "./interfaces/IDNT.sol";

contract SiriusAdapter {

    using Address for address payable;
    using Address for address;

    uint8 public idxNtoken;
    uint8 public idxToken;

    address[] public stakers;

    mapping(address => uint256) public lpBalances;
    mapping(address => uint256) public gaugeBalances;
    mapping(address => uint256) public srsBalances;
    mapping(address => bool) public isStaker;
    mapping(address => uint) public stakersIdx;

    address public token;

    //Interfaces
    ISiriusPool public pool;
    ISiriusFarm public farm;
    IDNT public lp;
    IDNT public nToken;
    IDNT public gauge;
    IDNT public srs;

    constructor(
        ISiriusPool _pool,
        ISiriusFarm _farm,
        IDNT _lp,
        IDNT _nToken,
        IDNT _gauge,
        IDNT _srs,
        address _token
    ) {
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
    // @param _autoStake If true LP tokens go to stake at the same tx
    function addLiquidity(uint256[] calldata _amounts, bool _autoStake) external payable update {
        uint256 tokensAmount = _amounts[0];
        uint256 nTokensAmount = _amounts[1];

        require(msg.value == tokensAmount, "Wrong value");
        require(tokensAmount == nTokensAmount, "The number of tokens should be the same");

        nToken.transferFrom(msg.sender, address(this), nTokensAmount);

        uint256 lpAmount = pool.addLiquidity{value: tokensAmount}(_amounts, 0, block.timestamp + 1200);
        lpBalances[msg.sender] += lpAmount;

        if (_autoStake) {
            this.depositLP(lpAmount);
        }
    }

    // @notice Remove liquidity from the pool
    // @param _amounts The amounts of each token to add
    //        idx 0 is ASTR, idx 1 is nASTR
    function removeLiquidity(uint256[] memory _amounts) external update {
        uint256 userLpBalance = lpBalances[msg.sender];
        uint256 estimateLpAmount = pool.calculateTokenAmount(_amounts, false);

        require(estimateLpAmount <= userLpBalance, "Not enough LP");
        require(_amounts[0] == _amounts[1], "The number of tokens should be the same");

        uint256 beforeTokens = address(this).balance;
        uint256 beforeNtokens = nToken.balanceOf(address(this));

        uint256 burnedLp = pool.removeLiquidityImbalance(_amounts, userLpBalance, block.timestamp + 1200);

        uint256 afterNtokens = nToken.balanceOf(address(this));
        uint256 afterTokens = address(this).balance;

        uint256 receivedTokens = afterTokens - beforeTokens;
        uint256 receivedNtokens = afterNtokens - beforeNtokens;

        lpBalances[msg.sender] -= burnedLp;

        nToken.transfer(msg.sender, receivedNtokens);
        payable(msg.sender).sendValue(receivedTokens);
    }

    // @notice Deposit LP tokens to farm pool and receives Gauge tokens instead
    // @param _amount Amount of LP tokens
    function depositLP(uint256 _amount) external update {
        require(lpBalances[msg.sender] >= _amount, "Not enough LP tokens");

        uint256 beforeGauge = gauge.balanceOf(address(this));
        farm.deposit(_amount, address(this), false);
        uint256 afterGauge = gauge.balanceOf(address(this));
        uint256 receivedGauge = afterGauge - beforeGauge;

        gaugeBalances[msg.sender] += receivedGauge;
        lpBalances[msg.sender] -= _amount;

        stakers.push(msg.sender);
        isStaker[msg.sender] = true;
        stakersIdx[msg.sender] = stakers.length - 1;
    }

    // @notice Receives LP tokens back instead of Gauge
    // @param _amount Amount of Gauge tokens
    // @param _autoWithdraw If true remove all liquidity at the same tx
    function withdrawLP(uint256 _amount, bool _autoWithdraw) external update {
        require(gaugeBalances[msg.sender] >= _amount, "Not enough Gauge tokens");

        uint256 beforeLp = lp.balanceOf(address(this));
        farm.withdraw(_amount, false);
        uint256 afterLp = lp.balanceOf(address(this));
        uint256 received = afterLp - beforeLp;

        gaugeBalances[msg.sender] -= received;
        lpBalances[msg.sender] += received;

        if (gaugeBalances[msg.sender] == 0) {
            isStaker[msg.sender] = false;
            uint idx = stakersIdx[msg.sender];
            stakers[idx] = stakers[stakers.length - 1];
            stakers.pop();
        }

        if (_autoWithdraw) {
            uint256 userLpBalance = lpBalances[msg.sender];
            this.removeLiquidity(pool.calculateRemoveLiquidity(userLpBalance));
        }
    }

    // @notice Claim all rewards by users
    function claim() external update {
        require(srsBalances[msg.sender] >= 0, "There are no any rewards");
        require(!msg.sender.isContract(), "Only for external owned accounts");

        uint256 amount = srsBalances[msg.sender];
        srsBalances[msg.sender] = 0;
        srs.transfer(msg.sender, amount);
    }

    // @notice Get share of n tokens in pool for user
    // @param _user User's address
    function getShare(address _user) external view returns (uint256 nShare) {
        uint256 virtualPrice = pool.getVirtualPrice() / 10**18;
        uint256 nTokensInPool = pool.getTokenBalance(idxNtoken);
        uint256 tokensInPool = pool.getTokenBalance(idxToken);
        nShare = ((lpBalances[_user] + gaugeBalances[_user]) * virtualPrice) * nTokensInPool / (tokensInPool + nTokensInPool);
    }

    // @dev function helper, will be deleted
    function getUserBalances(address _user) external view returns (
        uint256 lpToken,
        uint256 gaugeToken,
        uint256 srsToken
    ) {
        lpToken = lpBalances[_user];
        gaugeToken = gaugeBalances[_user];
        srsToken = srsBalances[_user];
    }

    // @dev function helper, will be deleted
    function getAdapterBalances() external view returns (
        uint256 lpTokens,
        uint256 gaugeTokens,
        uint256 srsTokens,
        uint256 nTokens,
        uint256 tokens
    ) {
        lpTokens = lp.balanceOf(address(this));
        gaugeTokens = gauge.balanceOf(address(this));
        srsTokens = srs.balanceOf(address(this));
        nTokens = nToken.balanceOf(address(this));
        tokens = address(this).balance;
    }

    // @notice Receives SRS rewards and distribute them between users
    //         according to their shares
    function _globalClaim() private {
        uint256 beforeSrs = srs.balanceOf(address(this));
        farm.claimRewards(address(this), address(0));
        uint256 afterSrs = srs.balanceOf(address(this));
        uint256 receivedSrs = afterSrs - beforeSrs;

        for (uint i; i < stakers.length; i++) {
            uint share = gaugeBalances[stakers[i]] * 10**18 / gauge.balanceOf(address(this));
            uint userRewards = receivedSrs * share / 10**18;
            srsBalances[stakers[i]] += userRewards;
        }
    }

    // @notice At each transaction _globalClaim calls
    modifier update() {
        _globalClaim();
        _;
    }
}
