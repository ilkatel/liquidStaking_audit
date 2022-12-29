// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract LiquidStakingManager is AccessControlUpgradeable {
    bytes32 public constant MANAGER = keccak256("MANAGER");

    address public diamondAddress;
    bool public paused;

    address[] public addresses;
    mapping(address => uint256) addressIndex;

    mapping(address => bytes4[]) public addressSelectors;
    mapping(address => mapping(bytes4 => uint256)) selectorIndex;

    mapping(bytes4 => address) public selectorToAddress;

    // Init ------------------------------------------------------------------------------
    // -----------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }  

    function initialize() public initializer {
        paused = false;
        _grantRole(MANAGER, msg.sender);
    }

    // Pausable logic --------------------------------------------------------------------
    // -----------------------------------------------------------------------------------

    modifier whenNotPaused() {
        require(!paused || hasRole(MANAGER, msg.sender), "Contract paused");
        _;
    }

    function pause() external {
        require(!paused, "Already paused");
        paused = true;
    }

    function unpause() external {
        require(paused, "Not paused");
        paused = false;
    }

    // Management logic ------------------------------------------------------------------
    // -----------------------------------------------------------------------------------

    /// @notice function for issuing <MANAGER> role to an account.
    /// @param account => account address.
    function addManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MANAGER, account);
    }

    /// @notice function for removind <MANAGER> role to an account.
    /// @param account => account address.
    function removeManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANAGER, account);
    }

    // External funcs --------------------------------------------------------------------
    // -----------------------------------------------------------------------------------

    function getAddress(bytes4 selector) external view whenNotPaused returns (address) {
        address addressFromSelector = selectorToAddress[selector];
        require(addressFromSelector != address(0), "Function does not exist");
        return addressFromSelector;
    }

    function addSelector(bytes4 selector, address addressFromSelector) public onlyRole(MANAGER) {
        require(selectorToAddress[selector] == address(0), "Selector already setted for given address");
        require(addressFromSelector != address(0), "Incorrect address");
        require(selector != bytes4(0), "Incorrect selector");

        selectorToAddress[selector] = addressFromSelector;

        _addSelector(selector, addressFromSelector);
    }

    function addSelectorsBatch(bytes4[] memory selectors, address addressFromSelector) external {
        uint256 l = selectors.length;
        for (uint256 i; i < l; i++) {
            bytes4 selector = selectors[i];
            if(selectorToAddress[selector] == address(0))
                addSelector(selector, addressFromSelector);
        }
    }

    function deleteSelector(bytes4 selector) public onlyRole(MANAGER) {
        require(selectorToAddress[selector] != address(0), "The selector was not set");
        selectorToAddress[selector] = address(0);

        _deleteSelector(selector);
    }

    function changeSelector(bytes4 oldSelector, bytes4 newSelector) external onlyRole(MANAGER) {
        require(selectorToAddress[newSelector] == address(0), "The new selector already has an address");
        address addressFromSelector = selectorToAddress[oldSelector];
        deleteSelector(oldSelector);
        addSelector(newSelector, addressFromSelector);
    }

    function deleteAllAddressSelectors(address _address) external onlyRole(MANAGER) {
        uint256 l = addressSelectors[_address].length;
        require(l > 0, "Unknown address");

        for (uint256 i; i < l; i++) deleteSelector(addressSelectors[_address][i]);
    }

    // View funcs ------------------------------------------------------------------------
    // -----------------------------------------------------------------------------------

    function getAddressSelectors(address _address) external view returns (bytes4[] memory) {
        return addressSelectors[_address];
    }

    function getAddresses() external view returns (address[] memory) {
        return addresses;
    }

    // Private funcs ---------------------------------------------------------------------
    // -----------------------------------------------------------------------------------

    function _addAddress(address _address) private {
        addressIndex[_address] = addresses.length;
        addresses.push(_address);
    }

    function _deleteAddress(address _address) private {
        uint256 index = addressIndex[_address];
        uint256 lastIndex = addresses.length - 1;
        address lastAddress = addresses[lastIndex];

        addressIndex[lastAddress] = index;
        addresses[index] = lastAddress;

        addresses.pop();
    }   

    function _addSelector(bytes4 selector, address addressFromSelector) private {
        if (addressSelectors[addressFromSelector].length == 0) _addAddress(addressFromSelector);

        selectorIndex[addressFromSelector][selector] = addressSelectors[addressFromSelector].length;
        addressSelectors[addressFromSelector].push(selector);
    }

    function _deleteSelector(bytes4 selector) private {
        address addressFromSelector = selectorToAddress[selector];

        uint256 index = selectorIndex[addressFromSelector][selector];
        uint256 lastIndex = addressSelectors[addressFromSelector].length - 1;
        bytes4 lastSelector = addressSelectors[addressFromSelector][lastIndex];

        addressSelectors[addressFromSelector][index] = addressSelectors[addressFromSelector][lastIndex];
        selectorIndex[addressFromSelector][lastSelector] = index;

        addressSelectors[addressFromSelector].pop();

        if (addressSelectors[addressFromSelector].length == 0) _deleteAddress(addressFromSelector);
    }
}
