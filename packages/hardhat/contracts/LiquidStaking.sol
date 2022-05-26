// TODO:
//
// - Features:
// - - [ ] commissions
// - - [ ] another rewards except DNT
//
// - QoL:
// - - [+] tests
// - - [+] deployment
//

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./nDistributor.sol";
import "../libs/@openzeppelin/contracts/access/Ownable.sol";
import "../libs/@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Liquid staking contract
 */
contract LiquidStaking is Ownable {
    using Counters for Counters.Counter;


    // DECLARATIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKING SETTINGS
    // -------------------------------------------------------------------------------------------------------

    // @notice        core staking settings
    uint256   public    totalBalance;
    uint256   public    claimPool;
    uint256   public    minStake;
    uint256[] public    tfs; // staking timeframes

    // @notice DNT distributor
    address public distrAddr;
    NDistributor   distr;

    // @notice    nDistributor required values
    string public utilName = "LiquidStaking"; // Liquid Staking utility name
    string public DNTname  = "nASTR"; // DNT name

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKE MANAGEMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice Stake struct & identifier
    struct      Stake {
        uint256 totalBalance;
        uint256 liquidBalance;
        uint256 claimable;
        uint256 rate;

        uint256 startDate;
        uint256 finDate;
        uint256 lastUpdate;
    }

    // @notice Stakes & their IDs
    mapping(address => Stake) public stakes;

    // @notice staking events
    event Staked(address indexed who, uint256 amount, uint256 timeframe);
    event Claimed(address indexed who, uint256 amount);
    event Redeemed(address indexed who, uint256 amount);


    // MODIFIERS

    // @notice updates claimable stake values
    // @param  [uint256] id => stake ID
    modifier   updateStake() {

        Stake storage s = stakes[msg.sender];

        if (block.timestamp - s.lastUpdate < 1 days ) {
            _; // reward update once a day
        } else {
            claimPool -= s.claimable; // i am really sorry for this
            s.claimable = nowClaimable(msg.sender);
            claimPool += s.claimable; // i mean really
            s.lastUpdate = block.timestamp;
            _;
        }
    }


    // FUNCTIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- ADMIN
    // -------------------------------------------------------------------------------------------------------

    // @notice set distributor and DNT addresses, minimum staking amount
    // @param  [address] _distrAddr => DNT distributor address
    // @param  [uint256] _min => minimum value to stake
    constructor(address _distrAddr, uint256 _min) {

        // @dev set distributor address and contract instance
        distrAddr = _distrAddr;
        distr = NDistributor(distrAddr);

        minStake = _min;
        tfs.push(7 days);
    }

    // @notice add new timeframe
    // @param  [uint256] t => new timeframe value
    function   addTerm(uint256 t) external onlyOwner {
        tfs.push(t);
    }

    // @notice change timeframe value
    // @param  [uint8]   n => timeframe index
    // @param  [uint256] t => new timeframe value
    function   changeTerm(uint8 n, uint256 t) external onlyOwner {
        tfs[n] = t;
    }

    // @notice set distributor
    // @param  [address] a => new distributor address
    function   setDistr(address a) external onlyOwner {
        distrAddr = a;
        distr = NDistributor(distrAddr);
    }

    // @notice set minimum stake value
    // @param  [uint256] v => new minimum stake value
    function   setMinStake(uint256 v) external onlyOwner {
        minStake = v;
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Stake managment (stake/redeem tokens, claim DNTs)
    // -------------------------------------------------------------------------------------------------------

    // @notice create new stake with desired timeframe
    // @param  [uint8]   timeframe => desired timeframe index, chosen from tfs[] array
    function   stake(uint8 timeframe) external payable {
		require(msg.value >= minStake, "Value less than minimum stake amount");

        Stake storage s = stakes[msg.sender];
        uint256 val = msg.value;

        // @dev set user stake data
        s.totalBalance += val;
        s.claimable += val / 2;
        s.rate += val / 2 / tfs[timeframe] / 1 days;
        s.startDate = s.startDate == 0 ? block.timestamp : s.startDate;
        s.finDate = s.finDate == 0 ? block.timestamp + tfs[timeframe] : s.finDate + tfs[timeframe];
        s.lastUpdate = block.timestamp;

        // @dev update global balances and emit event
        totalBalance += val;
        claimPool += val / 2;

        emit Staked(msg.sender, val, tfs[timeframe]);
    }

    // @notice claim available DNT from stake
    // @param  [uint256] amount => amount of requested DNTs
    function   claim(uint256 amount) external updateStake {
        require(amount > 0, "Invalid amount!");


        Stake storage s = stakes[msg.sender];
        require(s.claimable >= amount, "Invalid amount >= claimable!");

        // @dev update balances
        s.claimable -= amount;
        s.liquidBalance += amount;
        claimPool -= amount;

        // @dev issue DNT and emit event
        distr.issueDnt(msg.sender, amount, utilName, DNTname);

        emit Claimed(msg.sender, amount);
    }

    // @notice redeem DNTs to retrieve native tokens from stake
    // @param  [uint256] amount => amount of tokens to redeem
    function   redeem(uint256 amount) external {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[msg.sender];
        // @dev can redeem only after finDate
        require(block.timestamp > s.finDate, "Cannot do it yet!");

        uint256 uBalance = distr.getUserDntBalanceInUtil(msg.sender, utilName, DNTname);
        require(uBalance >= amount, "Insuffisient DNT balance!");
        s.totalBalance -= amount;
        s.liquidBalance -= amount;
        totalBalance -= amount;

        // @dev burn DNT, send native token, emit event
        distr.removeDnt(msg.sender, amount, utilName, DNTname);
        payable(msg.sender).call{value: amount};

        emit Redeemed(msg.sender, amount);
    }

    // @notice returns the amount of DNTs available for claiming right now
    // @param  [uint256] id => stake ID
    // @return [uint256] amount => amount of claimable DNT right now
    function   nowClaimable(address u) public view returns (uint256 amount) {

        Stake memory s = stakes[u];

        if ( block.timestamp >= s.finDate) { // @dev if finDate already passed we can claim the rest
            amount = s.totalBalance - s.liquidBalance;
        } else if (block.timestamp - s.lastUpdate < 1 days) { // @dev don't change value if less than 1 day passed
            amount = s.claimable;
        } else { // @dev add claimable based on the amount of days passed
            uint256 d = (block.timestamp - s.lastUpdate) / 1 days;
            amount = s.claimable + s.rate * d;
        }
    }
}
