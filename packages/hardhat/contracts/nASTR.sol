// TODO:
// - create DNT distributor [+]
//
// - add events for the platform
//
// - set up upgradability proxy
// - set up transparent upgradability

// rinkeby addr: 0xb82F0bBd0B3285050529Db3D02E8f2D0D1343E5E

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../libs/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../libs/@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../libs/@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "../libs/@openzeppelin/contracts/access/Ownable.sol";
import "../libs/@openzeppelin/contracts/security/Pausable.sol";
import "../libs/@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

interface INDistributor {
    function transferDnt(address, address, uint256, string memory, string memory) external;
}

interface ILiquidStaking {
    function addStaker(address) external;
    function get_stakers() external view returns(address[] memory);
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
contract NASTR is ERC20, ERC20Burnable, ERC20Snapshot, Ownable, Pausable, ERC20Permit {

    INDistributor distributor;
    ILiquidStaking liquidStaking;

    // @notice      contract constructor
    // @param       [address] _distributor => DNT distributor contract address (will become the owner)
    constructor(address _distributor, address _liquidStaking) ERC20("ASTR Note", "nASTR") ERC20Permit("ASTR Note") {
        transferOwnership(_distributor);
        distributor = INDistributor(_distributor);
        liquidStaking = ILiquidStaking(_liquidStaking);
    }

    // @param       issue DNT token
    // @param       [address] to => token reciever
    // @param       [uint256] amount => amount of tokens to issue
    function mintNote(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // @param       destroy DNT token
    // @param       [address] to => token holder to burn from
    // @param       [uint256] amount => amount of tokens to burn
    function burnNote(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    // @param       create snapshot of balances
    function snapshot() public onlyOwner {
        _snapshot();
    }

    // @param       pause the token
    function pause() public onlyOwner {
        _pause();
    }

    // @param       resume token if paused
    function unpause() public onlyOwner {
        _unpause();
    }

    // @param       checks if token is active
    // @param       [address] from => address to transfer tokens from
    // @param       [address] to => address to transfer tokens to
    // @param       [uint256] amount => amount of tokens to transfer
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function transfer(address _to, uint256 _amount) override public returns (bool) {
        address owner = _msgSender();
        distributor.transferDnt(owner, _to, _amount, "LiquidStaking", "nASTR");
        // check if recepient in rewards list and add him if not
        address[] memory stakers = liquidStaking.get_stakers();
        bool recepientStaker;
        uint length = stakers.length;
        for (uint i; i < length;) {
            if (stakers[i] == _to) {
                recepientStaker = true;
                break;
            }
            unchecked { ++i; }
        }
        if (!recepientStaker) {
            liquidStaking.addStaker(_to);
        }
        return true;
    }
}
