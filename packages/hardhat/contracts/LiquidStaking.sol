// TODO:
//
// - Features: 
// - - [ ] commissions
// - - [ ] another rewards except DNT
//
// - QoL:
// - - [+/-] tests, orders TBD
// - - [ ] deployment
//
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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
    uint256[] public  tfs; // staking timeframes

    // @notice DNT distributor
    address public distrAddr;
    NDistributor   distr;

    // @notice    nDistributor required values
    string public utilName = "LS"; // Liquid Staking utility name
    string public DNTname  = "nASTR"; // DNT name

    mapping(address => mapping(uint256 => bool)) public isStakeOwner;
    mapping(address => mapping(uint256 => bool)) public isOrderOwner;


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKE MANAGEMENT 
    // -------------------------------------------------------------------------------------------------------
    
    // @notice Stake struct & identifier
    Counters.Counter stakeIDs;
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
    mapping(uint256 => Stake) public stakes;

    // @notice staking events
    event Staked(address indexed who, uint256 stakeID, uint256 amount, uint256 timeframe);
    event Claimed(address indexed who, uint256 stakeID, uint256 amount);
    event Redeemed(address indexed who, uint256 stakeID, uint256 amount);


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- ORDER MANAGEMENT 
    // -------------------------------------------------------------------------------------------------------
    
    // @notice Order struct & identifier
    Counters.Counter orderIDs;
    struct      Order {
        bool    active;
        address owner;
        uint256 stakeID;
        uint256 price;
    }
    
    // @notice Orders & their IDs
    mapping(uint256 => Order) public orders;

    // @notice order events
    event OrderChange(uint256 id, address indexed seller, bool state, uint256 price);
    event OrderComplete(uint256 id, address indexed seller, address indexed buyer, uint256 price);


    // MODIFIERS

    // @notice checks if msg.sender owns the stake
    // @param  [uint256] id => stake ID
    modifier stakeOwner(uint256 id) {
        require(isStakeOwner[msg.sender][id], "Invalid stake owner!");
        _;
    }

    // @notice checks if msg.sender owns the order
    // @param  [uint256] id => order ID
    modifier orderOwner(uint256 id) {
        require(isOrderOwner[msg.sender][id], "Invalid order owner!");
        _;
    }

    // @notice updates claimable stake values
    // @param  [uint256] id => stake ID
    modifier updateStake(uint256 id) {

        Stake storage s = stakes[id];

        if (block.timestamp - s.lastUpdate < 1 days ) {
            _; // reward update once a day
        } else {
            claimPool -= s.claimable; // i am really sorry for this
            s.claimable = nowClaimable(id);
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
    }

    // @notice add new timeframe
    // @param  [uint256] t => new timeframe value
    function addTerm(uint256 t) external onlyOwner {
        tfs.push(t);
    }

    // @notice change timeframe value
    // @param  [uint8]   n => timeframe index
    // @param  [uint256] t => new timeframe value
    function changeTerm(uint8 n, uint256 t) external onlyOwner {
        tfs[n] = t;
    }

    // @notice set distributor
    // @param  [address] a => new distributor address
    function setDistr(address a) external onlyOwner {
        distrAddr = a;
        distr = NDistributor(distrAddr);
    }

    // @notice set minimum stake value
    // @param  [uint256] v => new minimum stake value
    function setMinStake(uint256 v) external onlyOwner {
        minStake = v;
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Stake managment (stake/redeem tokens, claim DNTs)
    // -------------------------------------------------------------------------------------------------------

    // @notice create new stake with desired timeframe
    // @param  [uint8]   timeframe => desired timeframe index, chosen from tfs[] array
    // @return [uint256] id => ID of created stake
    function stake(uint8 timeframe) external payable returns (uint256 id) {
		require(msg.value >= minStake, "Value less than minimum stake amount");

        uint256 val = msg.value;

        // @dev create new stake
        id = stakeIDs.current();
        stakeIDs.increment();
        stakes[id] = Stake ({
            totalBalance: val,
            liquidBalance: 0,
            claimable: val / 2,
            rate: val / 2 / tfs[timeframe] / 1 days,
            startDate: block.timestamp,
            finDate: block.timestamp + tfs[timeframe],
            lastUpdate: block.timestamp
        });
        isStakeOwner[msg.sender][id] = true;

        // @dev update global balances and emit event
        totalBalance += val;
        claimPool += val / 2;

        emit Staked(msg.sender, id, val, tfs[timeframe]);
    }

    // @notice claim available DNT from stake
    // @param  [uint256] id => stake ID
    // @param  [uint256] amount => amount of requested DNTs
    function claim(uint256 id, uint256 amount) external stakeOwner(id) updateStake(id) {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[id];
        require(s.claimable >= amount, "Invalid amount!");

        // @dev update balances
        s.claimable -= amount;
        s.liquidBalance += amount;
        claimPool -= amount;

        // @dev issue DNT and emit event
        distr.issueDnt(msg.sender, amount, utilName, DNTname);

        emit Claimed(msg.sender, id, amount);
    }

    // @notice redeem DNTs to retrieve native tokens from stake
    // @param  [uint256] id => stake ID
    // @param  [uint256] amount => amount of tokens to redeem
    function redeem(uint256 id, uint256 amount) external stakeOwner(id) {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[id];
        // @dev can redeem only after finDate
        require(block.timestamp > s.finDate, "Cannot do it yet!");

        uint256 uBalance = distr.getUserDntBalanceInUtil(msg.sender, utilName, DNTname);
        require(uBalance >= amount, "Insuffisient DNT balance!");
        s.totalBalance -= amount;
        totalBalance -= amount;

        // @dev burn DNT, send native token, emit event
        distr.removeDnt(msg.sender, amount, utilName, DNTname);
        payable(msg.sender).call{value: amount};

        emit Redeemed(msg.sender, id, amount);
    }

    // @notice returns the amount of DNTs available for claiming right now
    // @param  [uint256] id => stake ID
    // @return [uint256] amount => amount of claimable DNT right now
    function nowClaimable(uint256 id) public view returns (uint256 amount) {

        Stake memory s = stakes[id];

        if ( block.timestamp >= s.finDate) { // @dev if finDate already passed we can claim the rest
            amount = s.totalBalance - s.liquidBalance;
        } else if (block.timestamp - s.lastUpdate < 1 days) { // @dev don't change value if less than 1 day passed
            amount = s.claimable;
        } else { // @dev add claimable based on the amount of days passed
            uint256 d = (block.timestamp - s.lastUpdate) / 1 days;
            amount = s.claimable + s.rate * d;
        }
    }


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Order managment (sell/buy stakes, cancel order)
    // -------------------------------------------------------------------------------------------------------

    // @notice create new sell order
    // @param  [uint256] id => ID of stake to sell
    // @param  [uint256] price => desired stake price
    // @return [uint256] orderID => ID of created order
    function createOrder(uint256 id, uint256 price) external stakeOwner(id) returns (uint256 orderID) {
        require(price > 0, "Invalid price!");
        require(isStakeOwner[msg.sender][id], "Not your stake!");
        require(stakes[id].totalBalance > 0, "Empty stake!");

        // @dev create new order and add it to user orders
        orderID = orderIDs.current();
        orderIDs.increment();
        orders[orderID] = Order ({
            active: true,
            owner: msg.sender,
            stakeID: id,
            price: price
        });
        isOrderOwner[msg.sender][orderID] = true;

        emit OrderChange(orderID, msg.sender, true, orders[id].price);
    }

    // @notice cancel created order
    // @param  [uint256] id => order ID
    function cancelOrder(uint256 id) external orderOwner(id) {

        Order storage o = orders[id];

        require(o.active, "Inactive order!");

        o.active = false;

        emit OrderChange(id, msg.sender, false, o.price);
    }

    // @notice set new order price
    // @param  [uint256] id => order ID
    // @param  [uint256] p => new order price
    function setPrice(uint256 id, uint256 p) external orderOwner(id) {

        orders[id].price = p;

        emit OrderChange(id, msg.sender, true, p);
    }

    // @notice buy stake with particular order
    // @param  [uint256] id => order ID
    function buyStake(uint256 id) external payable {
        require(!isOrderOwner[msg.sender][id], "It's your order!");

        Order storage o = orders[id];

        require(o.active, "Inactive order!");
        require(msg.value == o.price, "Insuffisient value!");

        // @dev set order inactive
        o.active = false;

        // @dev change ownership
        isStakeOwner[o.owner][o.stakeID] = false;
        isStakeOwner[msg.sender][o.stakeID] = true;

        // @dev current amount of minted DNT for this stake
        uint256 liquid = stakes[o.stakeID].liquidBalance;

        // @dev update DNT balances if there were any
        if (liquid  > 0) {
            distr.removeDnt(o.owner, liquid, utilName, DNTname);
            distr.issueDnt(msg.sender, liquid, utilName, DNTname);
        }

        // @dev finally pay
        payable(o.owner).call{value: msg.value};

        emit OrderComplete(id, o.owner, msg.sender, o.price);
    }
}