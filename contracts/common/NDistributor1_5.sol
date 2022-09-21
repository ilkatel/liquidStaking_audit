// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IDNT.sol";
import "./interfaces/ILiquidStaking.sol";

/*
 * @notice ERC20 DNT token distributor contract
 *
 * Features:
 * - Initializable
 * - AccessControlUpgradeable
 */
contract NDistributor1_5 is AccessControl {
    // DECLARATIONS
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- USER MANAGMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice describes DntAsset structure
    // @dev    dntInUtil => describes how many DNTs are attached to specific utility
    struct DntAsset {
        mapping(string => uint256) dntInUtil;
        string[] userUtils;
        uint256 dntLiquid; // <= will be removed in the next update
    }

    // @notice describes user structure
    // @dev    dnt => tracks specific DNT token
    struct User {
        mapping(string => DntAsset) dnt;
        string[] userDnts;
        string[] userUtilities;
    }

    // @dev    users => describes the user and his portfolio
    mapping(address => User) users;

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- UTILITY MANAGMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice describes utility (Algem offer\opportunity) struct
    struct Utility {
        string utilityName;
        bool isActive;
    }

    // @notice keeps track of all utilities
    Utility[] public utilityDB;

    // @notice allows to list and display all utilities
    string[] public utilities;

    // @notice keeps track of utility ids
    mapping(string => uint) public utilityId;

    // -------------------------------------------------------------------------------------------------------
    // -------------------------------- DNT TOKENS MANAGMENT
    // -------------------------------------------------------------------------------------------------------

    // @notice defidescribesnes DNT token struct
    struct Dnt {
        string dntName;
        bool isActive;
    }

    // @notice keeps track of all DNTs
    Dnt[] public dntDB;

    // @notice allows to list and display all DNTs
    string[] public dnts;

    // @notice keeps track of DNT ids
    mapping(string => uint) public dntId;

    // @notice DNT token contract interface
    IDNT DNTContract;

    // @notice stores DNT contract addresses
    mapping(string => address) public dntContracts;

    // -------------------------------------------------------------------------------------------------------
    // -------------------------------- ACCESS CONTROL ROLES
    // -------------------------------------------------------------------------------------------------------

    // @notice stores current contract owner
    address public owner;

    // @notice stores addresses with privileged access
    address[] public managers;
    mapping(address => uint256) public managerIds;

    // @notice manager contract role
    bytes32 public constant MANAGER = keccak256("MANAGER");

    ILiquidStaking liquidStaking;
    mapping(address => bool) private isPool;

    mapping(string => bool) public disallowList;
    mapping(string => uint) public totalDntInUtil;

    mapping(string => bool) public isUtility;

    // @notice thanks to this varibale the func setup() will be called only once
    bool private isCalled;

    // @notice needed to show if the user has dnt
    mapping(address => mapping(string => bool)) public userHasDnt;

    // @notice needed to show if the user has utility
    mapping(address => mapping(string => bool)) public userHasUtility;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint _amount,
        string _utility,
        string indexed _dnt
    );
    event IssueDnt(
        address indexed _to,
        uint indexed _amount,
        string _utility,
        string indexed _dnt
    );

    using Address for address;

    mapping(string => uint256) public totalDnt;
    
    string public generalAdapter;
    string public adaptersUtility;
    // MODIFIERS
    //
    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- MODIFIERS
    // -------------------------------------------------------------------------------------------------------
    modifier dntInterface(string memory _dnt) {
        _setDntInterface(_dnt);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        owner = msg.sender;

        // empty utility needs to start indexing from 1 instead of 0
        // utilities will exclude the "empty" utility,
        // and the index will differ from the one in utilityDB
        utilityDB.push(Utility("empty", false));
        dntDB.push(Dnt("empty", false));

        utilityDB.push(Utility("null", true));
        utilityId["null"] = 1;
        utilities.push("null");

        uint lastId = dntDB.length;

        string memory _name = "nASTR-Adapters";
        dntId[_name] = lastId;
        dntDB.push(Dnt(_name, true));
        dnts.push(_name);
        dntContracts[_name] = address(0);
        
        lastId = dntDB.length;

        _name = "GeneralAdapter";
        generalAdapter = _name;
        dntId[_name] = lastId;
        dntDB.push(Dnt(_name, true));
        dnts.push(_name);
        dntContracts[_name] = address(0);

        lastId = utilityDB.length;

        _name = "AdaptersUtility";
        adaptersUtility = _name;
        utilityId[_name] = lastId;
        utilityDB.push(Utility(_name, true));
        utilities.push(_name);
        isUtility[_name] = true;
    }   

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Role managment
    // -------------------------------------------------------------------------------------------------------

    /// @notice changes owner roles
    /// @param _newOwner => new contract owner
    function changeOwner(address _newOwner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newOwner != address(0), "Zero address alarm!");
        require(_newOwner != owner, "Trying to set the same owner");
        _grantRole(DEFAULT_ADMIN_ROLE, _newOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, owner);
        owner = _newOwner;
    }

    /// @notice returns the list of all managers
    function listManagers() external view returns (address[] memory) {
        return managers;
    }

    /// @notice adds manager role
    /// @param _newManager => new manager to add
    function addManager(address _newManager)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newManager != address(0), "Zero address alarm!");
        require(!hasRole(MANAGER, _newManager), "Allready manager");
        managerIds[_newManager] = managers.length;
        managers.push(_newManager);
        _grantRole(MANAGER, _newManager);
    }

    /// @notice removes manager role
    /// @param _manager => new manager to remove
    function removeManager(address _manager)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        hasRole(MANAGER, _manager);
        uint256 id = managerIds[_manager];

        // delete managers[id];
        managers[id] = managers[managers.length - 1];
        managers.pop();

        _revokeRole(MANAGER, _manager);
        managerIds[_manager] = 0;
    }

    /// @notice removes manager role
    /// @param _oldAddress => old manager address
    /// @param _newAddress => new manager address
    function changeManagerAddress(address _oldAddress, address _newAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_newAddress != address(0), "Zero address alarm!");
        removeManager(_oldAddress);
        addManager(_newAddress);
    }

    function addUtilityToDissalowList(string memory _utility)
        public
        onlyRole(MANAGER)
    {
        disallowList[_utility] = true;
    }

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Asset managment (utilities and DNTs tracking)
    // -------------------------------------------------------------------------------------------------------

    /// @notice returns the list of all utilities
    function listUtilities() external view returns (string[] memory) {
        return utilities;
    }

    /// @notice returns the list of all DNTs
    function listDnts() external view returns (string[] memory) {
        return dnts;
    }

    /// @notice adds new utility to the DB, activates it by default
    /// @param _newUtility => name of the new utility
    function addUtility(string memory _newUtility)
        external
        onlyRole(MANAGER)
    {
        require(!isUtility[_newUtility], "Utility already added");
        uint lastId = utilityDB.length;
        utilityId[_newUtility] = lastId;
        utilityDB.push(Utility(_newUtility, true));
        utilities.push(_newUtility);
        isUtility[_newUtility] = true;
    }

    /// @notice adds new DNT to the DB, activates it by default
    /// @param _newDnt => name of the new DNT
    /// @param _dntAddress => address of the new dnt
    function addDnt(string memory _newDnt, address _dntAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_dntAddress.isContract(), "_dntaddress should be contract");
        require(dntContracts[_newDnt] != _dntAddress, "Dnt already added");
        uint lastId = dntDB.length;

        dntId[_newDnt] = lastId;
        dntDB.push(Dnt(_newDnt, true));
        dnts.push(_newDnt);
        dntContracts[_newDnt] = _dntAddress;
    }

    /// @notice allows to change DNT asset contract address
    /// @param _dnt => name of the DNT
    /// @param _address => new address
    function changeDntAddress(string memory _dnt, address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_address.isContract(), "_address should be contract address");
        dntContracts[_dnt] = _address;
    }

    /// @notice allows to activate\deactivate utility
    /// @param _id => utility id
    /// @param _state => desired state
    function setUtilityStatus(uint256 _id, bool _state)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        utilityDB[_id].isActive = _state;
    }

    /// @notice allows to activate\deactivate DNT
    /// @param _id => DNT id
    /// @param _state => desired state
    function setDntStatus(uint256 _id, bool _state)
        public
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        dntDB[_id].isActive = _state;
    }

    /// @notice returns a list of user's DNT tokens in possession
    /// @param _user => user address
    /// @return userDnts => all user dnts
    function listUserDnts(address _user) public view returns (string[] memory) {
        return users[_user].userDnts;
    }

    /// @notice returns user utilities by DNT
    /// @param _user => user address
    /// @param _dnt => dnt name
    /// @return userUtils => all user utils in dnt
    function listUserUtilitiesInDnt(address _user, string memory _dnt) public view returns (string[] memory) {
        return users[_user].dnt[_dnt].userUtils;
    }

    /// @notice returns user dnt balances in utilities
    /// @param _user => user address
    /// @param _dnt => dnt name
    /// @return dntBalances => dnt balances in utils
    /// @return usrUtils => all user utils in dnt
    function listUserDntInUtils(address _user, string memory _dnt) external view returns (string[] memory, uint256[] memory) {
        string[] memory _utilities = listUserUtilitiesInDnt(_user, _dnt);

        uint256 l = _utilities.length;
        require(l > 0, "Have no used utilities");

        DntAsset storage _dntAsset = users[_user].dnt[_dnt];
        uint256[] memory _dnts = new uint256[](l);

        for (uint256 i; i < l; i++) {
            _dnts[i] = _dntAsset.dntInUtil[_utilities[i]];
        }
        return (_utilities, _dnts);
    }

    /// @notice returns ammount of DNT toknes of user in utility
    /// @param _user => user address
    /// @param _util => utility name
    /// @param _dnt => DNT token name
    /// @return dntBalance => user dnt balance in util
    function getUserDntBalanceInUtil(
        address _user,
        string memory _util,
        string memory _dnt
    ) public view returns (uint256) {
        return users[_user].dnt[_dnt].dntInUtil[_util];
    }

    /// @notice returns which utilities are used with specific DNT token
    /// @param _user => user address
    /// @param _dnt => DNT token name
    /// @return utilsList => all user utils are used with specific DNT token
    function getUserUtilsInDnt(address _user, string memory _dnt)
        public
        view
        returns (string[] memory)
    {
        return users[_user].dnt[_dnt].userUtils;
    }

    /// @notice returns user's DNT balance
    /// @param _user => user address
    /// @param _dnt => DNT token name
    /// @return dntBalance => current user balance in dnt
    function getUserDntBalance(address _user, string memory _dnt)
        public
        dntInterface(_dnt)
        returns (uint256)
    {
        return DNTContract.balanceOf(_user);
    }

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Distribution logic
    // -------------------------------------------------------------------------------------------------------

    /// @notice add to user dnt and util if he doesn't have them
    /// @param _to => user address
    /// @param _dnt => dnt name
    /// @param _utility => util name
    function _addToUser(
        address _to, 
        string memory _dnt, 
        string memory _utility
    ) internal {
        if (!userHasDnt[_to][_dnt]) {
            _addDntToUser(_to, _dnt);
        }
        if (!userHasUtility[_to][_utility]) {
            _addUtilityToUser(_to, _dnt, _utility);
        }
    }

    /// @notice remove from user dnt and util if he has them
    /// @param _from => user address
    /// @param _dnt => dnt name
    /// @param _utility => util name
    function _removeFromUser(
        address _from, 
        string memory _dnt, 
        string memory _utility
    ) internal {
        if (userHasUtility[_from][_utility]) {
            _removeUtilityFromUser(
                _utility, 
                users[_from].userUtilities
            );
            _removeUtilityFromUser(
                _utility,
                users[_from].dnt[_dnt].userUtils
            );
            userHasUtility[_from][_utility] = false;
        }
        if (userHasDnt[_from][_dnt] && users[_from].dnt[_dnt].userUtils.length == 0) {
            _removeDntFromUser(
                _dnt,
                users[_from].userDnts
            );
            userHasDnt[_from][_dnt] = false;
        }
    }

    /// @notice issues new tokens
    /// @param _to => token recepient
    /// @param _amount => amount of tokens to mint
    /// @param _utility => minted dnt utility
    /// @param _dnt => minted dnt
    function issueDnt(
        address _to,
        uint256 _amount,
        string memory _utility,
        string memory _dnt
    ) external dntInterface(_dnt) {
        require(_to != address(0), "Zero address alarm!");
        require(msg.sender == address(liquidStaking), "Only for LiquidStaking");
        require(
            utilityDB[utilityId[_utility]].isActive == true,
            "Invalid utility!"
        );

        _addToUser(_to, _dnt, _utility);

        users[_to].dnt[_dnt].dntInUtil[_utility] += _amount;
        DNTContract.mintNote(_to, _amount);

        totalDnt[_dnt] += _amount;
        totalDntInUtil[_utility] += _amount;
        liquidStaking.updateUserBalanceInUtility(_utility, _to);


        emit IssueDnt(_to, _amount, _utility, _dnt);
    }

    /// @notice set user dnt balance in adapter util
    /// @param _user => user address
    /// @param _dnt => dnt name
    /// @param _utility => utility name
    /// @param _value => new balance value
    /// @dev function will be used by adapters to control balances in adapters
    function setUserAdapterBalance(address _user, string memory _dnt, string memory _utility, uint256 _value) external onlyRole(MANAGER) {
        require(utilityDB[utilityId[_utility]].isActive, "Adapter not active");

        uint256 balanceBefore = users[_user].dnt[_dnt].dntInUtil[_utility];
        users[_user].dnt[_dnt].dntInUtil[_utility] = _value;

        users[_user].dnt[generalAdapter].dntInUtil[adaptersUtility] += _value - balanceBefore;
        
        liquidStaking.updateUserBalanceInUtility(adaptersUtility, _user);
    }

    /// @notice issues new transfer tokens
    /// @param _to => token recepient
    /// @param _amount => amount of tokens to mint
    /// @param _utility => minted dnt utility
    /// @param _dnt => minted dnt
    function issueTransferDnt(
        address _to,
        uint256 _amount,
        string memory _utility,
        string memory _dnt
    ) public onlyRole(MANAGER) dntInterface(_dnt) {
        require(_to != address(0), "Zero address alarm!");
        require(
            utilityDB[utilityId[_utility]].isActive == true,
            "Invalid utility!"
        );

        _addToUser(_to, _dnt, _utility);

        users[_to].dnt[_dnt].dntInUtil[_utility] += _amount;
        liquidStaking.updateUserBalanceInUtility(
            _utility, 
            _to
        );
        
    }

    /// @notice ads dnt to user
    /// @param _to => user address
    /// @param _dnt => dnt name
    function _addDntToUser(address _to, string memory _dnt)
        internal
        onlyRole(MANAGER)
    {
        require(dntDB[dntId[_dnt]].isActive == true, "Invalid DNT!");

        users[_to].userDnts.push(_dnt);
        userHasDnt[_to][_dnt] = true;
    }

    /// @notice add to user utility by dnt
    /// @param _to => user address
    /// @param _dnt => dnt name
    /// @param _utility => name of the utility token
    function _addUtilityToUser(
        address _to,
        string memory _dnt,
        string memory _utility
    ) internal onlyRole(MANAGER) {
        require(
            utilityDB[utilityId[_utility]].isActive == true, 
            "Invalid utility!"
        );

        users[_to].userUtilities.push(_utility);
        users[_to].dnt[_dnt].userUtils.push(_utility);
        userHasUtility[_to][_utility] = true;
    }

    /// @notice removes tokens from circulation
    /// @param _from => address to burn from
    /// @param _amount => amount of tokens to burn
    /// @param _utility => minted dnt utility
    /// @param _dnt => minted dnt
    function removeDnt(
        address _from,
        uint256 _amount,
        string memory _utility,
        string memory _dnt
    ) external onlyRole(MANAGER) dntInterface(_dnt) {
        require(
            utilityDB[utilityId[_utility]].isActive == true,
            "Invalid utility!"
        );

        require(
            users[_from].dnt[_dnt].dntInUtil[_utility] >= _amount,
            "Not enough DNT in utility!"
        );
        
        totalDntInUtil[_utility] -= _amount;
        totalDnt[_dnt] -= _amount;

        DNTContract.burnNote(_from, _amount, _utility);
        
        liquidStaking.updateUserBalanceInUtility(_utility, _from);
    }

    /// @notice removes transfer tokens from circulation
    /// @param _from => address to burn from
    /// @param _amount => amount of tokens to burn
    /// @param _utility => minted dnt utility
    /// @param _dnt => minted dnt
    function removeTransferDnt(
        address _from,
        uint256 _amount,
        string memory _utility,
        string memory _dnt
    ) public onlyRole(MANAGER) dntInterface(_dnt) {
        require(
            utilityDB[utilityId[_utility]].isActive == true,
            "Invalid utility!"
        );

        require(
            users[_from].dnt[_dnt].dntInUtil[_utility] >= _amount,
            "Not enough DNT in utility!"
        );

        users[_from].dnt[_dnt].dntInUtil[_utility] -= _amount;
        liquidStaking.updateUserBalanceInUtility(
            _utility, 
            _from
        );

        if (users[_from].dnt[_dnt].dntInUtil[_utility] == 0) {
            _removeFromUser(_from, _dnt, _utility);
        }
    }

    /// @notice removes utility string from user array of utilities
    /// @param _utility => name of the utility token
    /// @param localUserUtilities => array of user's utilities
    function _removeUtilityFromUser(
        string memory _utility,
        string[] storage localUserUtilities
    ) internal onlyRole(MANAGER) {
        uint l = localUserUtilities.length;

        for (uint i; i < l; i++) {
            if (
                keccak256(abi.encodePacked(localUserUtilities[i])) ==
                keccak256(abi.encodePacked(_utility))
            ) {
                // delete localUserUtilities[i];
                localUserUtilities[i] = localUserUtilities[
                    localUserUtilities.length - 1
                ];
                localUserUtilities.pop();
                return;
            }
        }
    }

    /// @notice removes DNT string from user array of DNTs
    /// @param _dnt => name of the DNT token
    /// @param localUserDnts => array of user's DNTs
    function _removeDntFromUser(
        string memory _dnt,
        string[] storage localUserDnts
    ) internal onlyRole(MANAGER) {
        uint l = localUserDnts.length;

        for (uint i; i < l; i++) {
            if (
                keccak256(abi.encodePacked(localUserDnts[i])) ==
                keccak256(abi.encodePacked(_dnt))
            ) {
                localUserDnts[i] = localUserDnts[localUserDnts.length - 1];
                localUserDnts.pop();
                return;
            }
        }
    }

    /// @notice sends the specified number of tokens from the specified utilities
    /// @param _from => who sends
    /// @param _to => who gets
    /// @param _amounts => amounts of token
    /// @param _utilities => utilities to transfer
    /// @param _dnt => dnt to transfer
    function multiTransferDnts(
        address _from,
        address _to,
        uint256[] memory _amounts,
        string[] memory _utilities,
        string memory _dnt
    ) external onlyRole(MANAGER) {
        uint256 l = _utilities.length;
        for (uint256 i; i < l; i++) {
            if (_amounts[i] > 0) {
                transferDnt(_from, _to, _amounts[i], _utilities[i], _dnt);
            }
        }
    }

    /// @notice sends the specified amount from all user utilities
    /// @param _from => who sends
    /// @param _to => who gets
    /// @param _amount => amount of token
    /// @param _dnt => dnt to transfer
    function transferDnts(
        address _from,
        address _to,
        uint256 _amount,
        string memory _dnt
    ) external onlyRole(MANAGER) {
        string[] memory _utilities = users[_from].dnt[_dnt].userUtils;

        uint256 l = _utilities.length;
        for (uint256 i; i < l; i++) {
            uint256 senderBalance = users[_from].dnt[_dnt].dntInUtil[_utilities[i]];
            if (senderBalance > 0) {
                uint256 takeFromUtility = _amount > senderBalance ? senderBalance : _amount;

                transferDnt(_from, _to, takeFromUtility, _utilities[i], _dnt);
                _amount -= takeFromUtility;

                if (_amount == 0) return;  
            }          
        }
        revert("Not enough DNT");
    }

    /// @notice transfers tokens between users
    /// @param _from => token sender
    /// @param _to => token recepient
    /// @param _amount => amount of tokens to send
    /// @param _utility => transfered dnt utility
    /// @param _dnt => transfered DNT
    function transferDnt(
        address _from,
        address _to,
        uint256 _amount,
        string memory _utility,
        string memory _dnt
    ) public onlyRole(MANAGER)  {
        removeTransferDnt(_from, _amount, _utility, _dnt);
        if (_to != address(0)) {
            liquidStaking.addStaker(_to, _utility);
            issueTransferDnt(_to, _amount, _utility, _dnt);
        }

        emit Transfer(_from, _to, _amount, _utility, _dnt);
    }

    /// @notice allows to set a utility to free tokens (marked with null utility)
    /// @param _user => token owner
    /// @param _amount => amount of tokens to assign
    /// @param _newUtility => utility to set
    /// @param _dnt => DNT token
    function assignUtilityFromNull(
        address _user,
        uint256 _amount,
        string memory _newUtility,
        string memory _dnt
    ) external onlyRole(MANAGER) {
        require(dntDB[dntId[_dnt]].isActive == true, "Invalid DNT!");
        require(
            utilityDB[utilityId[_newUtility]].isActive == true,
            "Invalid utility!"
        );
        require(
            users[_user].dnt[_dnt].dntInUtil["null"] >= _amount,
            "Not enough free tokens!"
        );
        require(
            !disallowList[_newUtility],
            "Not cannot be assigned to this utility"
        );

        _reassignDntToUser(_user, _user, _amount, "null", _newUtility, _dnt);
    }

    /// @notice reassignes DNT tokens from one user to another
    /// @param _from => address to remove tokens from
    /// @param _to => address to add tokens to
    /// @param _amount => amount of tokens to reassign
    /// @param _utilityFrom => DNT utility to reassign from
    /// @param _utilityTo => DNT utility to reassign to
    /// @param _dnt => DNT token
    function _reassignDntToUser(
        address _from,
        address _to,
        uint256 _amount,
        string memory _utilityFrom,
        string memory _utilityTo,
        string memory _dnt
    ) internal onlyRole(MANAGER) dntInterface(_dnt) {
        require(
            utilityDB[utilityId[_utilityFrom]].isActive == true,
            "Invalid utility!"
        );
        require(
            utilityDB[utilityId[_utilityTo]].isActive == true,
            "Invalid utility!"
        );

        // remove tokens from user one
        require(
            users[_from].dnt[_dnt].dntInUtil[_utilityFrom] >= _amount,
            "Not enough DNT in utility!"
        );
        users[_from].dnt[_dnt].dntInUtil[_utilityFrom] -= _amount;
        if (users[_from].dnt[_dnt].dntInUtil[_utilityFrom] == 0) {
            _removeUtilityFromUser(_utilityFrom, users[_from].userUtilities);
            _removeUtilityFromUser(
                _utilityFrom,
                users[_from].dnt[_dnt].userUtils
            );
            userHasUtility[_from][_utilityFrom] = false;
        }

        // add tokens to user two
        _addToUser(_to, _dnt, _utilityTo);

        users[_to].dnt[_dnt].dntInUtil[_utilityTo] += _amount;
    }

    // -------------------------------------------------------------------------------------------------------
    // ------------------------------- Admin
    // -------------------------------------------------------------------------------------------------------

    /// @notice allows to specify DNT token contract address
    /// @param _dnt => dnt name
    function _setDntInterface(string memory _dnt) internal onlyRole(MANAGER) {
        address contractAddr = dntContracts[_dnt];

        require(contractAddr != address(0x00), "Invalid address!");
        require(dntDB[dntId[_dnt]].isActive == true, "Invalid Dnt!");

        DNTContract = IDNT(contractAddr);
    }

    /// @notice allows to transfer ownership of the DNT contract
    /// @param _to => new owner
    /// @param _dnt => name of the dnt token contract
    function transferDntContractOwnership(address _to, string memory _dnt)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        dntInterface(_dnt)
    {
        require(_to != address(0), "Zero address alarm!");
        DNTContract.transferOwnership(_to);
    }

    /// @notice overrides required by Solidity
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice sets Liquid Staking contract
    function setLiquidStaking(address _liquidStaking)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_liquidStaking.isContract(), "_liquidStaking should be contract");
        // require(address(liquidStaking) == address(0), "Already set");  // TODO: back
        liquidStaking = ILiquidStaking(_liquidStaking);
        _grantRole(MANAGER, _liquidStaking);
    }

    /// @notice      disabled revoke ownership functionality
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
        _revokeRole(role, account);
    }

    /// @notice      disabled revoke ownership functionality
    function renounceRole(bytes32 role, address account) public override {
        require(
            account == _msgSender(),
            "AccessControl: can only renounce roles for self"
        );
        require(
            role != DEFAULT_ADMIN_ROLE,
            "Not allowed to renounce admin role"
        );
        _revokeRole(role, account);
    }

    function setup() external onlyRole(MANAGER) {
        require(!isCalled, "Allready called");
        isCalled = true;
        isUtility["LiquidStaking"] = true;
        isUtility["null"] = true;
    }
}
