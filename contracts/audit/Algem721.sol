// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "./NFTDistributor.sol";

contract Algem721 is ERC721PresetMinterPauserAutoIdUpgradeable {

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    NFTDistributor public nftDistr;

    string public utilName;
    string public _baseTokenURI;
    uint256 public maxSupply;

    bool public initialized;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }  

    function initialize(
        string memory name, 
        string memory symbol, 
        string memory baseTokenURI
    ) public override initializer {
        super.initialize(name, symbol, baseTokenURI);
        _baseTokenURI = baseTokenURI;

        _grantRole(MANAGER_ROLE, msg.sender);
    }   

    function initialize2(
        address _nftDistr,
        string memory _utilName,
        uint256 _maxSupply
    ) external onlyRole(MANAGER_ROLE) {
        require(!initialized, "Already initialized!");
        initialized = true;
        nftDistr = NFTDistributor(_nftDistr);
        utilName = _utilName;
        maxSupply = _maxSupply;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function haveTokens(address account) external view returns (bool) {
        return ERC721Upgradeable.balanceOf(account) > 0;
    }

    function changeBaseURI(string memory baseTokenURI_) external onlyRole(MANAGER_ROLE) {
        _baseTokenURI = baseTokenURI_;
    }

    function changeMaxSupply(uint256 _maxSupply) external onlyRole(MANAGER_ROLE) {
        require(_maxSupply >= totalSupply(), "Incorrect supply value");
        maxSupply = _maxSupply;
    }

    function mintBatch(address[] memory accounts) public {
        uint256 l = accounts.length;
        require(totalSupply() + l - 1 < maxSupply, "Token limit reached");

        for (uint256 i = 0; i < l; ) {
            super.mint(accounts[i]);
            unchecked { ++i; }
        }
    }

    modifier updates() {
        nftDistr.updates();
        _;
    }

    function mint(address to) public override updates {
        require(totalSupply() < maxSupply, "Token limit reached");

        super.mint(to);
    }

    function burn(uint256 _tokenId) public override {
        revert("Cant burn tokens");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._beforeTokenTransfer(from, to, tokenId);
        nftDistr.transferNft(utilName, from, to, 1);
    }

    function addManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MANAGER_ROLE, account);
    }

    function removeManager(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANAGER_ROLE, account);
    }

    /// @notice disabled revoke ownership functionality
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
        _revokeRole(role, account);
    }
}  
