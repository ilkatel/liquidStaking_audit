//TODO:
//
// - Token transfer function (should keep track of user utils)
// - User structure — should describe the "vault" of the user — keep track of his assets and utils [+]
// - Make universal DNT interface
// - Make sure ownership over DNT tokens isn't lost
//
// - Write getter functions to read info about user vaults (users mapping)

// SET-UP:
// 1. Deploy nDistributor
// 2. Deploy nASTR, pass distributor address as constructor arg (makes nDistributor the owner)
// 3. Call "setAstrInterface" in nDistributor with nASTR contract address

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/DNTInterface.sol";

/*
 * @notice ERC20 DNT token distributor contract
 *
 * Features:
 * - Ownable
 */
contract nDistributor is Ownable {

    // ------------------------------- USER MANAGMENT

    // @notice                         describes DntAsset structure
    // @dev                            dntInUtil => describes how many DNTs are attached to specific utility
    // @dev                            dntLiquid => describes how many DNTs are liquid and available for imidiate use
    struct                             DntAsset {
        mapping (string => uint256)    dntInUtil;
        uint256                        dntLiquid;
    }

    // @notice                         describes user structure
    // @dev                            dnt => tracks specific DNT token
    struct                             User {
        mapping (string => DntAsset)   dnt;
    }
    // @dev                            users => describes the user and his portfolio
    mapping (address => User)          users;

    // ------------------------------- UTILITY MANAGMENT

    // @notice                         defidescribesnes utility (Algem offer\opportunity) struct
    struct                             Utility {
        string                         utilityName;
        bool                           isActive;
    }
    // @notice                         keeps track of all utilities
    Utility[] public                   utilityDB;
    // @notice                         allows to list and display all utilities
    string[]                           utilities;
    // @notice                         keeps track of utility ids
    mapping (string => uint) public    utilityId;

    // -------------------------------- DNT TOKENS MANAGMENT

    // @notice                          DNT token contract interface
    address public                      DNTContractAdress;
    DNTInterface                        DNTContract;

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- FUNCTIONS

    // @notice                         initializes utilityDB
    // @dev                            first element in mapping & non-existing entry both return 0
    //                                 so we initialize it to avoid confusion
    constructor() {
        utilityDB.push(Utility("null", false));
        DNTContractAdress = address(0x00);
    }

    // @notice                          allows to specify nASTR token contract address
    // @param                           [address] _contract => nASTR contract address
    function                            setAstrInterface(address _contract) external onlyOwner {
        DNTContractAdress = _contract;
        DNTContract = DNTInterface(DNTContractAdress);
    }

    // @notice                         returns the list of all utilities
    function                           listUtilities() external view returns(string[] memory) {
        return utilities;
    }

    // @notice                         adds new utility to the DB, activates it by default
    // @param                          [string] _newUtility => name of the new utility
    function                           addUtility(string memory _newUtility) external onlyOwner {
        uint                           lastId = utilityDB.length;

        utilityId[_newUtility] = lastId;
        utilityDB.push(Utility(_newUtility, true));
        utilities.push(_newUtility);
    }

    // @notice                         allows to activate\deactivate utility
    // @param                          [uint256] _id => utility id
    // @param                          [bool] _state => desired state
    function                           setUtilityStatus(uint256 _id, bool _state) public onlyOwner {
        utilityDB[_id].isActive = _state;
    }

    // @notice                         issues new tokens
    // @param                          [address] _to => token recepient
    // @param                          [uint256] _amount => amount of tokens to mint
    // @param                          [string] _utility => minted dnt utility
    // @param                          [string] _dnt => minted dnt
    function                           issueDNT(address _to, uint256 _amount, string memory _utility, string memory _dnt) public {
        uint256                        id;
        address                        user = msg.sender;

        require(DNTContractAdress != address(0x00), "Interface not set!");
        require((id = utilityId[_utility]) > 0, "Non-existing utility!");
        users[user].dnt[_dnt].dntInUtil[_utility] += _amount;
        users[user].dnt[_dnt].dntLiquid += _amount;
        DNTContract.mintNote(_to, _amount);

    }

    // @notice                         removes tokens from circulation
    // @param                          [address] _account => address to burn from
    // @param                          [uint256] _amount => amount of tokens to burn
    // @param                          [string] _utility => minted dnt utility
    // @param                          [string] _dnt => minted dnt
    function                           removeDNT(address _account, uint256 _amount, string memory _utility, string memory _dnt) public {
        uint256                        id;
        address                        user = msg.sender;

        require(DNTContractAdress != address(0x00), "Interface not set!");
        require((id = utilityId[_utility]) > 0, "Non-existing utility!");
        require((users[user].dnt[_dnt].dntInUtil[_utility] - _amount) > 0, "Not enough DNT in utility!");
        require((users[user].dnt[_dnt].dntLiquid - _amount) > 0, "Not enough liquid DNT!");
        users[user].dnt[_dnt].dntInUtil[_utility] += _amount;
        users[user].dnt[_dnt].dntLiquid += _amount;
        DNTContract.burnNote(_account, _amount);
    }

    // transfer tokens (should keep track of util)
}
