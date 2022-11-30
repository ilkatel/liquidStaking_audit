// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ILiquidStaking.sol";
import "./NFTDistributor.sol";

contract AdaptersDistributor is AccessControl {
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant ADAPTER = keccak256("ADAPTER");

    ILiquidStaking public liquidStaking;
    NFTDistributor public nftDistr;

    string public utilName;

    uint256 public totalAmount;
    mapping(address => uint256) userAmount;

    struct Adapter {
        address contractAddress;
        uint256 totalAmount;
        mapping(address => uint256) userAmount;
    }

    mapping(string => Adapter) public adapters;
    mapping(string => bool) public haveAdapter;
    mapping(string => uint256) public adapterId;
    string[] adaptersList;

    constructor(address _liquidStaking) {
        liquidStaking = ILiquidStaking(_liquidStaking);
        utilName = "AdaptersUtility";

        _grantRole(MANAGER, msg.sender); 
    }  

    function addAdapter(address _contractAddress, string memory _utility) external onlyRole(MANAGER) {
        require(_contractAddress != address(0), "Incorrect address");
        require(!haveAdapter[_utility], "Already have adapter");

        haveAdapter[_utility] = true;

        /* currently unused, commented to save gas
        adapterId[_utility] = adaptersList.length;
        adaptersList.push(_utility);
        */

        adapters[_utility].contractAddress = _contractAddress;

        _grantRole(ADAPTER, _contractAddress);
    }

    function removeUtility(string memory _utility) public onlyRole(MANAGER) {
        require(haveAdapter[_utility], "Adapter not found");

        address adapterAddress = adapters[_utility].contractAddress;

        haveAdapter[_utility] = false;

        /* currently unused, commented to save gas
        uint256 _adapterId = adapterId[_utility];
        adaptersList[_adapterId] = adaptersList[adaptersList.length - 1];
        adapterId[adaptersList[_adapterId]] = _adapterId;
        adaptersList.pop();
        */

        _revokeRole(ADAPTER, adapterAddress);
    }
    
    /// @notice function to update user balance in adapters.
    /// @param _adapter => utility name.
    /// @param user => address of user to update.
    /// @param amountAfter => the current balance of the user in the adapter.
    /// @dev the function will call from adapters.
    /// after which the LiquidStaking contract will update the user's balance in the "AdapterUtility".
    function updateBalanceInAdapter(string memory _adapter, address user, uint256 amountAfter) external onlyRole(ADAPTER) {
        uint256 amountBefore = adapters[_adapter].userAmount[user];

        if (amountBefore == amountAfter) return;

        totalAmount = totalAmount + amountAfter - amountBefore;
        userAmount[user] = userAmount[user] + amountAfter - amountBefore;
        adapters[_adapter].userAmount[user] = amountAfter;

        if (amountAfter > amountBefore) {
            nftDistr.transferDnt(utilName, address(0), user, amountAfter - amountBefore);
        } else {
            nftDistr.transferDnt(utilName, user, address(0), amountBefore - amountAfter);    
        }

        liquidStaking.updateUserBalanceInAdapter(utilName, user);
    }

    function getUserBalanceInAdapters(address user) external view returns (uint256) {
        return userAmount[user];
    }

    function setNftDistributor(address _nftDistr) external onlyRole(MANAGER) {
        nftDistr = NFTDistributor(_nftDistr);
    }
}
