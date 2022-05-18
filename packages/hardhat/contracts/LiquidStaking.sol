// TODO:
// - rewards calculation
// - proper staking timeframes management [+?]
// - DNT 
// - proper stake owner tracking [ ] -- need nDistributor transfer implementation?


//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./nDistributor.sol";
import "./nASTR.sol";
import "../libs/@openzeppelin/contracts/utils/Counters.sol";
import "../libs/@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title								Liquid staking contract
 * @notice								The idea: user stakes native tokens (ASTR)
 *        								and receives nASTR tokens in return. 
*/
contract LiquidStaking is Ownable {
	using Counters for Counters.Counter;

    // -------------------------------- DISTRIBUTOR
	// @notice							distributor address etc.
	address public						distrAddr;
	NDistributor						distr;

	address public						DNTAddr;
	NASTR						DNT;


    // -------------------------------- STAKING SETTINGS
	// @notice							minimum staking amount
	uint256 public						minStake;
	// @notice							stores staking timeframes, not sure if it's the right way
	uint256[] public					stakingTerms;

	
    // -------------------------------- STAKING MANAGEMENT
	Counters.Counter					stakeIDs;
	// @notice							single stake data
	struct								Stake {
		uint256							totalBalance;
		uint256							liquidBalance;
		uint256							rate;
		uint256							claimable;
		uint256							startDate;
		uint256							lastUpdate;
		uint256							finDate;
	}
	// @notice							store stakes by IDs
	mapping(uint256 => Stake) public	stakes;


    // -------------------------------- EVENTS
	// @notice events on calling stake/reedem, indexed by sender
	event Staked(address indexed from, uint256 amount, uint256 timeframe);
	event Reedemed(address indexed to, uint256 amount);
	event Claimed(address indexed to, uint256 indexed stakeID, uint256 amount);


    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- FUNCTIONS
	// @param							[address] _dAddr => distributor address
	// @param							[uint256] _min => minimum ASTR amount to stake
	constructor(address _distrAddr, address _DNTaddr, uint256 _min){
		distrAddr = _distrAddr;
		distr = NDistributor(distrAddr);
		DNTAddr = _DNTaddr;
		DNT = NASTR(DNTAddr);
		minStake = _min;
	}

	modifier updateStake(uint256 id) {
		Stake memory s = stakes[id];
		if (block.timestamp - s.lastUpdate > 3600 * 24) {
			stakes[id].lastUpdate = block.timestamp;
			stakes[id].claimable += s.rate;
		} 
		_;
	}

	// @notice							add new staking timeframe
	// @param							[uint256] newT => new staking timeframe to add
	function							addTerm(uint256 newT) external onlyOwner {
		stakingTerms.push(newT);
	}

	// @notice							change staking timeframe by index
	// @param							[uint8] termN => index of term to change
	// @param							[uint256] newT => new staking timeframe to add
	function							changeTerm(uint8 termN, uint256 newT) external onlyOwner {
		stakingTerms[termN] = newT;
	}

	// @notice							receive native tokens, save Stake data, give nASTR
	// @param							[uint8] termN => index of desired staking duration
	// @return							[uint256] id => ID of created stake
	function 							stake(uint8 termN) external payable returns (uint256 id) {

		// check if LS utility is active & we got enough value
		(, bool uActive) = distr.utilityDB(distr.utilityId("LS"));
		require(uActive, "Inactive utility!");
		require(msg.value >= minStake, "Value less than minimum stake amount");

		// create new Stake and store it in the mapping
		id = stakeIDs.current();
		stakeIDs.increment();
		stakes[id] = Stake({
			totalBalance: msg.value,
			liquidBalance: 0,
			rate: msg.value / 2 / stakingTerms[termN] / 3600 / 24,
			claimable: msg.value / 2,
			startDate: block.timestamp,
			lastUpdate: block.timestamp,
			finDate: block.timestamp + stakingTerms[termN]
		});

		// TODO: change minted amount to part of msg.value
		//distr.issueDNT(msg.sender, msg.value, "LS", "nASTR");
		emit Staked(msg.sender, msg.value, stakingTerms[termN]);
	}

	// @notice							check if Stake is redeemable, burn nASTR, send ASTR
	// @param							[uint256] id => Stake id
	// @param							[uint256] amount => reedem amount
	function 							reedem(uint256 id, uint256 amount) external {

		// should we check if utility is active?
		(, bool uActive) = distr.utilityDB(distr.utilityId("LS"));
		require(uActive, "Inactive utility!");

		require(amount > 0, "Invalid amount!");

		// get stake by id and check if conditions met
		Stake 							memory s = stakes[id];
		
		// check if user has dnt's
		//uint256 						uBalance = distr.users[msg.sender].dnt["nASTR"].dntInUtil["LS"];
		uint256							uBalance = DNT.balanceOf(msg.sender);
		require(uBalance >= amount, "Not enough DNTs!");

		require(s.totalBalance >= amount, "Cannot reedem more than stake balance!");
		require(s.finDate < block.timestamp, "Cannot do it yet!");

		// update Stake data
		stakes[id].totalBalance -= amount;

		// burn requested DNT amount from user
		distr.removeDNT(msg.sender, amount, "LS", "nASTR");

		// finally send ASTR to user
		payable(msg.sender).call{value: amount};
		emit Reedemed(msg.sender, amount);
	}

	/// @notice		claim rewards
	function claimDNT(uint256 id, uint256 amount) external updateStake(id) {
		Stake memory s = stakes[id];
		require(s.claimable >= amount, "Invalid amount!");

		stakes[id].claimable -= amount;
		stakes[id].liquidBalance += amount;

		distr.issueDNT(msg.sender, amount, "LS", "nASTR");
		// emit claimed
		emit Claimed(msg.sender, id, amount);
	}
}
