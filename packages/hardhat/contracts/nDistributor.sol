//TODO:
//
// - Token transfer function (should keep track of user utils)
// - User structure — should describe the "vault" of the user — keep track of his assets and utils
// - Make universal DNT interface

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./nASTRInterface.sol";

/*
 * @notice ERC20 DNT token distributor contract
 *
 * Features:
 * - Ownable
 */
contract nDistributor is Ownable {

    // ------------------------------- UTILITY MANAGMENT

    // @notice                         defines utility (Algem offer\opportunity) struct
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
    address                             nASTRInterfaceAddress = 0xd9145CCE52D386f254917e481eB44e9943F39138;
    nASTRInterface                      nASTRcontract = nASTRInterface(nASTRInterfaceAddress);

    // ------------------------------- FUNCTIONS

    // @notice                         initializes utilityDB
    // @dev                            first element in mapping & non-existing entry both return 0
    //                                 so we initialize it to avoid confusion
    constructor() {
        utilityDB.push(Utility("null", false));
    }

    // @notice                         returns the list of all utilities
    function                           returnUtilities() external view returns(string[] memory) {
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
    function                           issueDNT(address _to, uint256 _amount) public onlyOwner {
        nASTRcontract.mintNote(_to, _amount);
    }

    // @notice                         removes tokens from circulation
    // @param                          [address] _account => address to burn from
    // @param                          [uint256] _amount => amount of tokens to burn
    function                           removeDNT(address _account, uint256 _amount) public onlyOwner {
        nASTRcontract.burnNote(_account, _amount);
    }

    // transfer tokens (should keep track of util)
}
