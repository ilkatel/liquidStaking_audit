// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./NDistributor.sol";
import "./NFTDistributor.sol";

contract NASTR is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    ERC20Permit,
    Pausable,
    AccessControl
{
    bytes32 public constant DISTR_ROLE = keccak256("DISTR_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    NDistributor distributor;

    bool private isMultiTransfer;
    bool private isNote;
    string private utilityToTransfer;

    NFTDistributor public nftDistr;

    using Address for address;

    constructor(address _distributor) ERC20("Astar Note", "nASTR") ERC20Permit("Astar Note") {
        require(_distributor.isContract(), "_distributor should be contract address");
        _grantRole(DISTR_ROLE, _distributor);
        _grantRole(OWNER_ROLE, msg.sender);
        distributor = NDistributor(_distributor);
    }

    modifier noteTransfer(string memory utility) {
        utilityToTransfer = utility;
        isNote = true;
        _;
        isNote = false;
    }

    function setNftDistributor(address _nftDistr) external onlyRole(OWNER_ROLE) {
        nftDistr = NFTDistributor(_nftDistr);
    }

    // @param       issue DNT token
    // @param       [address] to => token reciever
    // @param       [uint256] amount => amount of tokens to issue
    function mintNote(address to, uint256 amount, string memory utility)
        external
        onlyRole(DISTR_ROLE)
        noteTransfer(utility)
    {
        _mint(to, amount);
    }

    /// @notice destroy DNT token
    /// @param account => token holder to burn from
    /// @param amount => amount of tokens to burn
    /// @param utility => utility to burn
    function burnNote(address account, uint256 amount, string memory utility)
        external
        onlyRole(DISTR_ROLE)
        noteTransfer(utility)
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

    uint256 counter;

    // @param       checks if token is active
    // @param       [address] from => address to transfer tokens from
    // @param       [address] to => address to transfer tokens to
    // @param       [uint256] amount => amount of tokens to transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);

        if (isNote) {
            distributor.transferDnt(from, to, amount, utilityToTransfer, "nASTR");
            nftDistr.transferDnt(utilityToTransfer, from, to, amount);
            counter++;
        } else if (!isMultiTransfer) {
            (string[] memory utilities, uint256[] memory amounts) = distributor.transferDnts(from, to, amount, "nASTR");
            nftDistr.multiTransferDnt(utilities, from, to, amounts);
        }

    }

    /* 1.5 upd */
    /// @notice transfer totens from selected utilities
    /// @param to => receiver address
    /// @param amounts => amounts of tokens to transfer
    /// @param utilities => utilities to transfer
    function transferFromUtilities(address to, uint256[] memory amounts, string[] memory utilities) external {
        require(utilities.length > 0, "Incorrect utilities array");
        require(utilities.length == amounts.length, "Incorrect arrays length");

        uint256 transferAmount = distributor.multiTransferDnts(msg.sender, to, amounts, utilities, "nASTR");
        require(transferAmount > 0, "Nothing to transfer");

        /// @dev set flag to ignore default _beforeTokenTransfer
        isMultiTransfer = true;
        _transfer(msg.sender, to, transferAmount);
        isMultiTransfer = false;

        nftDistr.multiTransferDnt(utilities, msg.sender, to, amounts);
    }
}