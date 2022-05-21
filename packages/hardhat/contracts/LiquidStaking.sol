//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./nDistributor.sol";
import "./nASTR.sol";
import "../libs/@openzeppelin/contracts/access/Ownable.sol";
import "../libs/@openzeppelin/contracts/utils/Counters.sol";

contract LiquidStaking is Ownable {
    using Counters for Counters.Counter;


    // DECLARATIONS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKING SETTINGS 
    // -------------------------------------------------------------------------------------------------------

    // @notice core staking settings
    string public utilName = "LS"; // Liquid Staking utility name
    string public DNTname = "nASTR"; // DNT name
    uint256 public totalBalance;
    uint256 public claimPool;
    uint256 public minStake;
    uint256[] public tfs; // staking timeframes

    // @notice DNT distributor
    address public distrAddr;
    NDistributor distr;

    // @notice DNT token
    address public DNTAddr;
    NASTR DNT;


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- STAKE MANAGEMENT 
    // -------------------------------------------------------------------------------------------------------
    
    // @notice single stake struct, stakes mapping
    Counters.Counter stakeIDs;
    struct Stake {
        address owner;

        uint256 totalBalance;
        uint256 liquidBalance;
        uint256 claimable;
        uint256 rate;

        uint256 startDate;
        uint256 finDate;
        uint256 lastUpdate;
    }
    mapping(uint256 => Stake) public stakes;
    mapping(address => uint256[]) public userStakes;

    // @notice staking events
    event Staked(address indexed who, uint256 stakeID, uint256 amount, uint256 timeframe);
    event Claimed(address indexed who, uint256 stakeID, uint256 amount);
    event Redeemed(address indexed who, uint256 stakeID, uint256 amount);


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- ORDER MANAGEMENT 
    // -------------------------------------------------------------------------------------------------------
    
    // @notice single order struct, orders mapping
    Counters.Counter orderIDs;
    struct Order {
        bool active;
        address owner;
        uint256 stakeID;
        uint256 price;
    }
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;

    // @notice order events
    event OrderChange(uint256 id, bool state, uint256 price);
    event OrderComplete(uint256 id, uint256 price);


    // MODIFIERS
    //
    // @notice checks if msg.sender owns the stake
    // @param [uint256] id => stake ID
    modifier stakeOwner(uint256 id) {
        require(stakes[id].owner == msg.sender);
        _;
    }

    // @notice updates claimable stake values
    // @param [uint256] id => stake ID
    modifier updateStake(uint256 id) {
        Stake storage s = stakes[id];
        if (block.timestamp - s.lastUpdate < 3600 * 24 ) {
            _;
        } else {
            claimPool -= s.claimable;
            s.claimable = nowClaimable(id);
            claimPool += s.claimable;
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
    // @param [address] _distrAddr => DNT distributor address
    // @param [address] _DNTaddr => DNT contract address
    // @param [uint256] _min => minimum value to stake
    constructor(address _distrAddr, address _DNTaddr, uint256 _min) {
        distrAddr = _distrAddr;
        distr = NDistributor(distrAddr);
        DNTAddr = _DNTaddr;
        DNT = NASTR(DNTAddr);
        minStake = _min;
    }

    // @notice add new timeframe
    // @param [uint256] newT => new timeframe value
    function addTerm(uint256 newT) external onlyOwner {
        tfs.push(newT);
    }

    // @notice change timeframe value
    // @param [uint8] termN => timeframe index
    // @param [uint256] newT => new timeframe value
    function changeTerm(uint8 termN, uint256 newT) external onlyOwner {
        tfs[termN] = newT;
    }

    // @notice set distributor
    // @param [address] newDistr => new distributor address
    function setDistr(address newDistr) external onlyOwner {
        distrAddr = newDistr;
        distr = NDistributor(distrAddr);
    }

    // @notice set DNT
    // @param [address] newDnt => new DNT address
    function setDNT(address newDNT) external onlyOwner {
        DNTAddr = newDNT;
        DNT = NASTR(DNTAddr);
    }

    // @notice set minimum stake value
    // @param [uint256] newMin => new minimum stake value
    function setMinStake(uint256 newMin) external onlyOwner {
        minStake = newMin;
    }

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Stake managment (stake/redeem tokens, claim DNTs)
    // -------------------------------------------------------------------------------------------------------

    // @notice create new stake with desired timeframe
    // @param [uint8] timeframe => desired timeframe index, chosen from tfs[] array
    // @return [uint256] id => ID of created stake
    function stake(uint8 timeframe) external payable returns (uint256 id) {
        // @dev check if there is enough value
		require(msg.value >= minStake, "Value less than minimum stake amount");

        // @dev create new stake
        id = stakeIDs.current();
        stakeIDs.increment();
        stakes[id] = Stake ({
            owner: msg.sender,
            totalBalance: msg.value,
            liquidBalance: 0,
            claimable: msg.value / 2,
            rate: msg.value / 2 / tfs[timeframe] / 24 / 3600,
            startDate: block.timestamp,
            finDate: block.timestamp + tfs[timeframe],
            lastUpdate: block.timestamp
        });
        // @dev add stake ID to user stakes
        userStakes[msg.sender].push(id);

        // @dev update global balances and emit event
        totalBalance += msg.value;
        claimPool += msg.value / 2;
        emit Staked(msg.sender, id, msg.value, tfs[timeframe]);
    }

    // @notice claim available DNT from stake
    // @param [uint256] id => stake ID
    // @param [uint256] amount => amount of requested DNTs
    function claim(uint256 id, uint256 amount) external stakeOwner(id) updateStake(id) {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[id];
        require(s.claimable >= amount, "Invalid amount!");

        // @dev update balances
        stakes[id].claimable -= amount;
        stakes[id].liquidBalance += amount;
        claimPool -= amount;

        // @dev issue DNT and emit event
        distr.issueDnt(msg.sender, amount, utilName, DNTname);
        emit Claimed(msg.sender, id, amount);
    }

    // @notice redeem DNTs to retrieve native tokens from stake
    // @param [uint256] id => stake ID
    // @param [uint256] amount => amount of tokens to redeem
    function redeem(uint256 id, uint256 amount) external stakeOwner(id) {
        require(amount > 0, "Invalid amount!");

        Stake storage s = stakes[id];
        // @dev can redeem only after finDate
        require(s.finDate < block.timestamp, "Cannot do it yet!");

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
    // @param [uint256] id => stake ID
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
    // @param [uint256] id => ID of stake to sell
    // @param [uint256] price => desired stake price
    // @return [uint256] orderID => ID of created order
    function createOrder(uint256 id, uint256 price) external stakeOwner(id) returns (uint256 orderID) {
        require(price > 0, "Invalid price!");
        Stake memory s = stakes[id];
        require(s.owner == msg.sender, "Not your stake!");
        require(s.totalBalance > 0, "Empty stake!");

        // @dev create new order and add it to userOrders
        orderID = orderIDs.current();
        orderIDs.increment();
        orders[orderID] = Order ({
            active: true,
            owner: msg.sender,
            stakeID: id,
            price: price
        });
        userOrders[msg.sender].push(id);

        emit OrderChange(orderID, true, orders[id].price);
    }

    function cancelOrder(uint256 id) external {
        Order storage o = orders[id];
        require(o.active, "Inactive order!");
        require(o.owner == msg.sender, "Not your order!");
        o.active = false;

        emit OrderChange(id, false, orders[id].price);
    }

    function buyStake(uint256 id) external payable {
        Order storage o = orders[id];
        require(o.active, "Inactive order!");
        require(o.owner != msg.sender, "Your order!");
        require(msg.value == o.price, "Insuffisient value!");
        o.active = false;
        stakes[o.stakeID].owner = msg.sender;
        payable(o.owner).call{value: msg.value};
        emit OrderComplete(id, o.price);
    }
}