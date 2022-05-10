// TODO:
// - rewards calculation
// - proper mint/burn
// - proper staking timeframes management
// - stake tracking via distributor(?)
// - events(?)


//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./nASTR.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title		Liquid staking contract
 * @notice		The idea: user stakes native tokens (ASTR)
 *        		and receives nASTR tokens in return. 
*/
contract LiquidStaking is Ownable {
	using Counters for Counters.Counter;
	Counters.Counter stakeIDs;

	/// @notice		nASTR token address
	address public nASTRtoken;
	/// @notice		minimum staking amount
	uint256 public minStake;
	/// @notice		stores staking timeframes, not sure if it's the right way
	uint256[] public stakingTerms;
	
	/// @notice		single stake data
	struct Stake {
		address owner;
		uint256 balance;
		uint256 startDate;
		uint256 finDate;
	}
	/// @notice		store stakes by IDs
	mapping(uint256 => Stake) public stakes;

	/// @param		[address] _token => nASTR token address
	/// @param		[uint256] _min => minimum ASTR amount to stake
	constructor(address _token, uint256 _min){
		nASTRtoken = _token;
		minStake = _min;
	}

	/// @notice		receive native tokens, save Stake data, give nASTR
	/// @param		[uint8] termN => index of desired staking duration
	/// @return		[uint256] id => ID of created stake
	function stake(uint8 termN) external payable returns (uint256 id) {

		///@notice	check if we received enough tokens to start staking
		require(msg.value >= minStake, "Value less than minimum stake amount");

		/// @notice	create new Stake and store it in the mapping
		id = stakeIDs.current();
		stakeIDs.increment();
		stakes[id] = Stake({
			owner: msg.sender,
			balance: msg.value,
			startDate: block.timestamp,
			finDate: block.timestamp + stakingTerms[termN]
		});

		/// @dev	I guess distributor has to handle it? 
		nASTR(nASTRtoken).mintNote(msg.sender, msg.value);
	}

	/// @notice		claim rewards
	function claim() external {

	}

	/// @notice		check if Stake is redeemable, burn nASTR, send ASTR
	/// @param		[uint256] id => Stake id
	/// @param		[uint256] amount => reedem amount
	function reedem(uint256 id, uint256 amount) external {

		/// @notice	get stake by id and check if conditions met
		Stake memory s = stakes[id];
		require(s.owner == msg.sender, "Invalid stake owner!");
		require(s.balance > 0, "Stake is empty!");
		require(s.balance >= amount, "Cannot reedem more than balance!");
		require(s.finDate < block.timestamp, "Cannot do it yet!");

		/// @notice	update Stake data
		stakes[id].balance -= amount;

		/// @dev	I guess distributor has to handle it? 
		nASTR(nASTRtoken).burnNote(msg.sender, amount);

		/// @notice	finally send ASTR to user
		payable(msg.sender).call{value: amount};
	}
}
