// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./interfaces/INDistributor.sol";

/*
 * @notice nASTR ERC20 DNT token contract
 *
 * https://docs.algem.io/dnts
 *
 * Features:
 * - Initializable
 * - ERC20Upgradeable
 * - ERC20BurnableUpgradeable
 * - ERC20SnapshotUpgradeable
 * - ERC20PermitUpgradeable
 * - PausableUpgradeable
 * - AccessControlUpgradeable
 */

contract NASTR is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20SnapshotUpgradeable,
    ERC20PermitUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant DISTR_ROLE = keccak256("DISTR_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    INDistributor distributor;

    using AddressUpgradeable for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // @notice      contract constructor
    // @param       [address] _distributor => DNT distributor contract address (will become the owner)
    function initialize(address _distributor) public initializer {
        require(_distributor.isContract(), "_distributor should be contract address");
        __ERC20_init("Astar Note", "nASTR");
        __ERC20Permit_init("Astar Note");
        __Pausable_init();
        __ERC20Burnable_init();
        __ERC20Snapshot_init();
        __AccessControl_init();
        _grantRole(DISTR_ROLE, _distributor);
        _grantRole(OWNER_ROLE, msg.sender);
        distributor = INDistributor(_distributor);
    }

    // @param       issue DNT token
    // @param       [address] to => token reciever
    // @param       [uint256] amount => amount of tokens to issue
    function mintNote(address to, uint256 amount)
        external
        onlyRole(DISTR_ROLE)
    {
        _mint(to, amount);
    }

    // @param       destroy DNT token
    // @param       [address] to => token holder to burn from
    // @param       [uint256] amount => amount of tokens to burn
    function burnNote(address account, uint256 amount)
        external
        onlyRole(DISTR_ROLE)
    {
        _burn(account, amount);
    }

    // @param       pause the token
    function pause() external onlyRole(OWNER_ROLE) {
        _pause();
    }

    // @param       resume token if paused
    function unpause() external onlyRole(OWNER_ROLE) {
        _unpause();
    }

    // @notice      disabled revoke ownership functionality
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
        _revokeRole(role, account);
    }

    // @notice      disabled revoke ownership functionality
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

    // @param       checks if token is active
    // @param       [address] from => address to transfer tokens from
    // @param       [address] to => address to transfer tokens to
    // @param       [uint256] amount => amount of tokens to transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount);
        if (from != address(0)) {
            distributor.transferDnt(from, to, amount, "LiquidStaking", "nASTR");
        }
    }
}
