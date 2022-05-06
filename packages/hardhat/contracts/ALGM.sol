// deployed to 0xCe5d8804009aE2239453Fc3dFd8caF377A77A9FF

// TODO:
// - set up roles for different distribution pools [+]
// - supply and distribution managment [+]
// - expose owner and owner transfer [+]
//
// - move funds from EOA to contracts
// - multisig for treasuries
// - add events for the platform
//
// - set up upgradability proxy
// - set up transparent upgradability

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

/*
 * @notice ALGM ERC20 governance token contract
 *
 * https://docs.algem.io/algm-token
 *
 * Features:
 * - Burnable
 * - Permits (gasless allowance)
 * - Votes (keeps track of historical balances)
 * - Role-based access control
 * - Snapshots (ability to store shnapshots of balances that can be retrieved later)
 */
contract ALGM is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, AccessControl {
    address public                     Owner;

    // @notice      contract roles
    bytes32 public constant            INCENTIVE_FUND = keccak256("INCENTIVE_FUND");
    bytes32 public constant            TEAM_FUND = keccak256("INCENTIVE_FUND");
    bytes32 public constant            COMMUNITY_FUND = keccak256("COMMUNITY_FUND");
    bytes32 public constant            RESERVE_FUND = keccak256("RESERVE_FUND");

    // @notice      token distribution among treasuries
    uint32 public constant      IncentiveDistrib = 60000000;
    uint32 public constant      TeamDistrib = 18000000;
    uint32 public constant      CommunityDistrib = 10000000;
    uint32 public constant      ReserveDistrib = 12000000;

    // @notice      time to release in years
    uint8 public constant      IncentiveTime = 6;
    uint8 public constant      TeamTime = 3;
    uint8 public constant      CommunityTime = 0;
    uint8 public constant      ReserveTime = 0;

    // @dev         stores treasury addresses
    struct Fund {
        address                 Incentive;
        address                 Team;
        address                 Community;
        address                 Reserve;
    } Fund public fund;

    // @notice      contract constructor
    // @param       [address] _incentive => Incentive treasury address
    // @param       [address] _team => Team treasury address
    // @param       [address] _community => Community treasury address
    // @param       [address] _reserve => Reserve treasury address
    constructor(address _incentive,
                address _team,
                address _community,
                address _reserve)
        ERC20("Algem Governance Token", "ALGM")
        ERC20Permit("Algem Governance Token")
    {
        // !!!!!! DEV !!!!!!!!! <------------------------------------------------------
        // dev remix
        // owner 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
        /* address _incentive = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        address _team = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
        address _community = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
        address _reserve = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2; */
        // !!!!!! DEV !!!!!!!!! <------------------------------------------------------

        // store treasury addresses
        fund.Incentive = _incentive;
        fund.Team = _team;
        fund.Community = _community;
        fund.Reserve = _reserve;

        // assign roles
        // use *onlyRole(ROLE)* modifier
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        Owner = msg.sender;
        _grantRole(INCENTIVE_FUND, fund.Incentive);
        _grantRole(TEAM_FUND, fund.Team);
        _grantRole(COMMUNITY_FUND, fund.Community);
        _grantRole(RESERVE_FUND, fund.Reserve);

        // mint total supply of 100,000,000
        _mint(msg.sender, 100000000 * 10 ** decimals());

        // distribute tokens between funds
        require(transfer(fund.Incentive, IncentiveDistrib * 10 ** decimals()) == true, "Incentive distribution failed!");
        require(transfer(fund.Team, TeamDistrib * 10 ** decimals()) == true, "Team distribution failed!");
        require(transfer(fund.Community, CommunityDistrib * 10 ** decimals()) == true, "Community distribution failed!");
        require(transfer(fund.Reserve, ReserveDistrib * 10 ** decimals()) == true, "Reserve distribution failed!");

        // !!!!!! DEV HARDHAT !!!!!!!!! <------------------------------------------------------
        /* _grantRole(DEFAULT_ADMIN_ROLE, 0xE2532766D03fd3796d826233924DE071AEb996d9);
        Owner = 0xE2532766D03fd3796d826233924DE071AEb996d9; */
        // !!!!!! DEV HARDHAT !!!!!!!!! <------------------------------------------------------
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function changeOwner(address _newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
      _grantRole(DEFAULT_ADMIN_ROLE, _newOwner);
      Owner = _newOwner;
    }

    // -----------------------------------------------------------
    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
