// TODO:
// - create DNT distributor [+]
//
// - add events for the platform
//
// - set up upgradability proxy
// - set up transparent upgradability

// rinkeby addr: 0xb82F0bBd0B3285050529Db3D02E8f2D0D1343E5E

// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


interface INDistributor {
    function transferDnt(address, address, uint256, string memory, string memory) external;
}

/*
 * @notice nALGM ERC20 DNT token contract
 *
 * https://docs.algem.io/dnts
 *
 * Features:
 * - Ownable
 * - Mintable
 * - Burnable
 * - Pausable
 * - Permits (gasless allowance)
 * - Snapshots (ability to store shnapshots of balances that can be retrieved later)
 */
 contract NSBY is Initializable,
    ERC20Upgradeable, ERC20BurnableUpgradeable, ERC20SnapshotUpgradeable, ERC20PermitUpgradeable,
    PausableUpgradeable, OwnableUpgradeable, AccessControlUpgradeable {

     bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
     bytes32 public constant DISTR_ROLE = keccak256("DISTR_ROLE");
     INDistributor distributor;

     // @notice      contract constructor
     // @param       [address] _distributor => DNT distributor contract address (will become the owner)
     function initialize(address _distributor) public initializer {
        __ERC20_init("Shibuya Note", "NSBY");
        __ERC20Permit_init("Shibuya Note");
        _grantRole(DISTR_ROLE, _distributor);
        distributor = INDistributor(_distributor);
     }
     /*
     constructor(address _distributor) ERC20("Shibuya Note", "NSBY") ERC20Permit("Shibuya Note") {
         transferOwnership(_distributor);
         distributor = INDistributor(_distributor);
     }
     */

     // @param       issue DNT token
     // @param       [address] to => token reciever
     // @param       [uint256] amount => amount of tokens to issue
     function mintNote(address to, uint256 amount) external onlyRole(DISTR_ROLE) {
         _mint(to, amount);
     }

     // @param       destroy DNT token
     // @param       [address] to => token holder to burn from
     // @param       [uint256] amount => amount of tokens to burn
     function burnNote(address account, uint256 amount) external onlyRole(DISTR_ROLE) {
         _burn(account, amount);
     }

     // @param       create snapshot of balances
     function snapshot() external returns (uint256) {
         require(hasRole(SNAPSHOT_ROLE, msg.sender), "Forbidden");
         return _snapshot();
     }

     // @param       pause the token
     function pause() external onlyOwner {
         _pause();
     }

     // @param       resume token if paused
     function unpause() external onlyOwner {
         _unpause();
     }

     // @param       checks if token is active
     // @param       [address] from => address to transfer tokens from
     // @param       [address] to => address to transfer tokens to
     // @param       [uint256] amount => amount of tokens to transfer
     function _beforeTokenTransfer(address from, address to, uint256 amount)
         internal
         whenNotPaused
         override(ERC20Upgradeable, ERC20SnapshotUpgradeable)
     {
         super._beforeTokenTransfer(from, to, amount);
         if (from != address(0)) {
             distributor.transferDnt(from, to, amount, "LiquidStaking", "NSBY");
         }
     }

 }
