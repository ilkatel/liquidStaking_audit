// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ILiquidStaking.sol";
import "./interfaces/IDNT.sol";
import "./NDistributor.sol";
import "./Algem721.sol";

contract NFTDistributor is AccessControl {
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant TOKEN_CONTRACT = keccak256("TOKEN_CONTRACT");

    uint8 public immutable LIQUIDSTAKING_FEE;

    ILiquidStaking public liquidStaking;
    NDistributor public distr;
    IDNT public nAstr;
    address public adaptersDistributor;

    string dntName; 

    struct User {   
        // stores the user's balance in each era.
        mapping(uint256 => uint256) eraAmount;
        // stores a boolean variable indicating whether the value is zero.
        mapping(uint256 => bool) isZeroAmount;
    }

    struct Utility {
        /// @custom:defimoon-note isUnique stores whether nft is unique.
        ///     true - unf is unique;
        ///     false - default nft.
        /// default NFTs give a reduced claim fee from any dapps, and unique ones give a reduced claim fee from one specific dapp.
        /// if the user has several nfts (default or unique), then the lowest possible fee will be selected for the brand from a certain dapp.
        bool isUnique;
        uint8 rewardFee;
        address contractAddress;
        uint256 totalAmount;

        // stores the utility balance in each era.
        mapping(uint256 => uint256) totalEraAmount;
        // stores a boolean variable indicating whether the value is zero.
        mapping(uint256 => bool) isZeroAmount;
        uint256 updatedEra;

        mapping(address => User) users;
    }

    struct UserInfo {
        // stores the current minimum commission among the user's default NFTs.
        uint8 defaultUserFee;
        // stores the current minimum commission among the user's default NFTs in each era.
        mapping(uint256 => uint8) eraDefaultUserFee;
        
        // stores the current total user balance staked in all dapps for which the user has a unique nft.
        // userBalanceInDapp_1  + ... + userBalanceInDapp_N
        uint256 totalUniqueBalance;
        // stores the current total user commission for all dapps in which he staked with unique nft.
        // userBalanceInDapp_1 * userDappFee_1 + ... + userBalanceInDapp_N * userDappFee_N
        uint256 totalUniqueComission;

        string[] uniqueUserNfts;
        string[] userNfts;

        mapping(string => bool) haveNft;
        mapping(string => bool) haveUniqueNft;
    }
    mapping(address => UserInfo) public users;

    // [0] - stores the total balance staked in all dapps from all users in each era.
    // [1] - stores the total comission for users staked in all dapps from all users in each era.
    mapping(uint256 => uint256[2]) totalEraData;
    mapping(uint256 => bool) isZeroData;
    uint256 updatedEra;

    mapping(string => Utility) public utils;
    mapping(string => bool) public haveUtil;
    mapping(string => uint256) public utilId;
    string[] utilsList;

    mapping(string => bool) public isUtilRemoved;

    constructor(
        address _distr,
        address _nAstr,
        address _liquidStaking,
        address _adaptersDistributor) {
        
        distr = NDistributor(_distr);
        nAstr = IDNT(_nAstr);
        liquidStaking = ILiquidStaking(_liquidStaking);

        LIQUIDSTAKING_FEE = liquidStaking.REVENUE_FEE();

        dntName = "nASTR";
        adaptersDistributor = _adaptersDistributor;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, _adaptersDistributor);
        _grantRole(MANAGER, msg.sender);   
        _grantRole(MANAGER, _liquidStaking);   
    }  

    // --------------------------------------------------------------------
    // Modifiers ----------------------------------------------------------
    // -------------------------------------------------------------------- 

    /// @notice modifier to update <totalEraData> for the current era.
    modifier globalUpdate() {
        uint256 era = liquidStaking.currentEra();
        if (era > updatedEra) {
            totalEraData[era] = totalEraData[updatedEra];
            isZeroData[era] = isZeroData[updatedEra];
            updatedEra = era;
        }
        _;
    }

    // --------------------------------------------------------------------
    // Management functions // used by LiquidStaking ----------------------
    // --------------------------------------------------------------------
    
    /// @notice function to calculate the summary <totalData> for the specified eras interval.
    /// @param eraBegin => Era to start.
    /// @param eraEnd => Era to end.
    /// @return totalData => summary <totalData> for given eras.
    function getErasData(uint256 eraBegin, uint256 eraEnd) 
    external 
    onlyRole(MANAGER) 
    globalUpdate 
    returns (uint256[2] memory totalData) {
        for (uint256 i = eraBegin; i < eraEnd; ) {
            uint256[2] memory _data = _getEraData(i);
            totalData[0] += _data[0];
            totalData[1] += _data[1];
            unchecked { ++i; }
        }
    }

    /// @notice function to update the user's fee.
    /// @param user => user address.
    /// @param fee => new fee.
    /// @param era => era in which to save new fee.
    function updateUserFee(address user, uint8 fee, uint256 era) external onlyRole(MANAGER) {
        if (users[user].eraDefaultUserFee[era] == 0) users[user].eraDefaultUserFee[era] = fee;
    }

    /// @notice function to update the user's balance in specified utility in specified era.
    /// @param utility => utility name.
    /// @param _user => user address.
    /// @param era => era in which to save new value.
    /// @param value => new user ara amount.
    function updateUser(string memory utility, address _user, uint256 era, uint256 value) external onlyRole(MANAGER) {
        User storage user = utils[utility].users[_user];

        user.eraAmount[era] = value;
        user.isZeroAmount[era] = value > 0 ? false : true;
    }
    
    // --------------------------------------------------------------------
    // Management functions // used by Tokens and AdaptersDistr contracts -
    // --------------------------------------------------------------------

    // *
    // used bu ERC721 NFT contracts
    // *

    /// @notice function to synchronization LiquidStaking contract before minting/burning nft.
    function updates() external onlyRole(TOKEN_CONTRACT) {
        uint256 era = liquidStaking.currentEra();
        try liquidStaking.sync(era) {} catch {}
    }

    /// @notice function for redistribution of balances and fees for the user when transferring nft.
    /// @param utility => utility name.
    /// @param from => sender's address. equals <address(0)> at mint.
    /// @param to => address of the recipient. equals <address(0)> at burn.
    /// @param amount => amount of sended nft.
    function transferNft(string memory utility, address from, address to, uint256 amount) external onlyRole(TOKEN_CONTRACT) globalUpdate {
        require(amount > 0, "Incorrect amount");
        if (from == to) return;

        Utility storage util_ = utils[utility];

        uint256 utilAmountBefore = util_.totalAmount;

        if (to != address(0)) {
            if (_addNftToUser(utility, to)) {
                uint256 utilityAmount = distr.getUserDntBalanceInUtil(to, utility, dntName);
                util_.totalAmount += utilityAmount;
                _updateUserBalance(utility, to, utilityAmount);
            }
        }

        if (from != address(0)) {
            if (_removeNftFromUser(utility, from, amount)) {
                util_.totalAmount -= distr.getUserDntBalanceInUtil(from, utility, dntName);
                _updateUserBalance(utility, from, 0);
            }
        }

        if (util_.totalAmount != utilAmountBefore) _updateTotalBalance(utility, util_.totalAmount);
    }

    // *
    // used by ERC20 DNT or AdaptersDistributor contracts
    // *

    /// @notice function for redistribution of balances and fees for the user when multi-transferring DNT tokens.
    /// @param utilities => array of utilities names.
    /// @param from => sender's address. equals <address(0)> at mint.
    /// @param to => address of the recipient. equals <address(0)> at burn.
    /// @param amounts => array of amounts sended DNT tokens.
    function multiTransferDnt(string[] memory utilities, address from, address to, uint256[] memory amounts) external globalUpdate {
        //require(msg.sender == address(nAstr) || msg.sender == adaptersDistributor, "Not access");
        require(msg.sender == address(nAstr), "Not access");

        uint256 l = utilities.length;
        for (uint256 i; i < l; i++) {
            _transferDnt(utilities[i], from, to, amounts[i]);
        }
    }

    /// @notice function for redistribution of balances and fees for the user when transferring DNT tokens.
    /// @param utility => utility name.
    /// @param from => sender's address. equals <address(0)> at mint.
    /// @param to => address of the recipient. equals <address(0)> at burn.
    /// @param amount => amount of sended DNT tokens.
    function transferDnt(string memory utility, address from, address to, uint256 amount) external globalUpdate {
        require(msg.sender == address(nAstr) || msg.sender == adaptersDistributor, "Not access");

        _transferDnt(utility, from, to, amount);
    }

    // --------------------------------------------------------------------
    // Management functions // used by admin ------------------------------
    // --------------------------------------------------------------------

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

    /// @notice disabled revoke ownership functionality
    function revokeRole(bytes32 role, address account)
        public
        override
        onlyRole(getRoleAdmin(role))
    {
        require(role != DEFAULT_ADMIN_ROLE, "Not allowed to revoke admin role");
        _revokeRole(role, account);
    }

    // --------------------------------------------------------------------
    // Management functions // used by manager ----------------------------
    // --------------------------------------------------------------------

    /// @notice function for adding new utility. 
    /// @param _contractAddress => nft contract address.
    /// @param _rewardFee => nft rewards fee.
    /// @param _isUnique => unique nft or default.
    /// @dev Nft contract must contain a <utilName()> corresponding to one of the dapps utility in LiquidStaking.
    function addUtility(address _contractAddress, uint8 _rewardFee, bool _isUnique) external onlyRole(MANAGER) {
        require(LIQUIDSTAKING_FEE >= _rewardFee, "Cant exceed default fee value");
        require(_rewardFee > 0, "Cant set zero fee");

        string memory _utilName = Algem721(_contractAddress).utilName();
        require(!isUtilRemoved[_utilName], "Utility blacklisted!");
        require(!haveUtil[_utilName], "Already have utility");

        utils[_utilName].rewardFee = _rewardFee;
        haveUtil[_utilName] = true;
        utilId[_utilName] = utilsList.length;
        utilsList.push(_utilName);
        utils[_utilName].contractAddress = _contractAddress;
        utils[_utilName].isUnique = _isUnique;

        _grantRole(TOKEN_CONTRACT, _contractAddress);
    }

    /// @notice function for removing utility. 
    /// @param _utilName => utility name.
    function removeUtility(string memory _utilName) public onlyRole(MANAGER) {
        require(haveUtil[_utilName], "Utility not found");

        address utilAddress = utils[_utilName].contractAddress;

        haveUtil[_utilName] = false;
        uint256 _utilId = utilId[_utilName];
        utilsList[_utilId] = utilsList[utilsList.length - 1];
        utilId[utilsList[_utilId]] = _utilId;
        utilsList.pop();

        isUtilRemoved[_utilName] = true;

        _revokeRole(TOKEN_CONTRACT, utilAddress);
    }

    /// @notice function for removing utility by nft contract address. 
    /// @param _contractAddress => nft contract address.
    function removeUtilityByAddress(address _contractAddress) external onlyRole(MANAGER) {
        string memory _utilName = Algem721(_contractAddress).utilName();
        removeUtility(_utilName);
    }

    // --------------------------------------------------------------------
    // Private logic functions // -----------------------------------------
    // --------------------------------------------------------------------

    /// @notice function for redistribution of balances and fees for the user when adding nft to user.
    /// @param utility => utility name.
    /// @param to => address of the recipient.
    /// @return isFirstNft => returns true if the user has not previously had such nfts.
    function _addNftToUser(string memory utility, address to) private returns (bool) {
        if (Algem721(utils[utility].contractAddress).balanceOf(to) == 0) {
            UserInfo storage user = users[to];

            uint256 era = liquidStaking.currentEra();

            if (utils[utility].isUnique) {
                _addNft(user.uniqueUserNfts, utility);
                user.haveUniqueNft[utility] = true;

                uint256 addBalance = distr.getUserDntBalanceInUtil(to, utility, dntName);

                user.totalUniqueBalance += addBalance;
                user.totalUniqueComission += addBalance * getUserFee(utility, to);
                
                if (user.userNfts.length > 0) {
                    if (user.defaultUserFee > utils[utility].rewardFee)
                        totalEraData[era][1] -= addBalance * (user.defaultUserFee - utils[utility].rewardFee);
                } else {
                    _updateUserFee(user, LIQUIDSTAKING_FEE, era);

                    totalEraData[era][0] += addBalance;
                    totalEraData[era][1] += addBalance * utils[utility].rewardFee;
                }
            } else {
                user.haveNft[utility] = true;
                if (_addNft(user.userNfts, utility)) {
                    _updateUserFee(user, utils[utility].rewardFee, era);
                    uint256 addBalance = nAstr.balanceOf(to);

                    totalEraData[era][0] += addBalance - user.totalUniqueBalance;
                    totalEraData[era][1] += (addBalance - user.totalUniqueBalance) * user.defaultUserFee;

                    _updateWithUniques(to, user.defaultUserFee, true);
                } else {
                    uint8 fee = utils[utility].rewardFee;
                    if (user.defaultUserFee > fee) {
                        totalEraData[era][1] -= (nAstr.balanceOf(to) - user.totalUniqueBalance) * (user.defaultUserFee - fee);
                        
                        _updateWithUniques(to, utils[utility].rewardFee, false);
                        _updateUserFee(user, fee, era);
                    }
                }
            }
            return true;
        }
        return false;
    }

    /// @notice function for redistribution of balances and fees for the user when removing nft to user.
    /// @param utility => utility name.
    /// @param from => sender's address.
    /// @param amount => amount of removing nfts;
    /// @return isLastNft => returns true if the user no longer has such nfts.
    function _removeNftFromUser(string memory utility, address from, uint256 amount) private returns (bool) {
        if (Algem721(utils[utility].contractAddress).balanceOf(from) <= amount) {
            UserInfo storage user = users[from];
            uint256 era = liquidStaking.currentEra();

            if (utils[utility].isUnique) {
                _removeNft(user.uniqueUserNfts, utility);
                user.haveUniqueNft[utility] = false;

                uint256 removedBalance = distr.getUserDntBalanceInUtil(from, utility, dntName);

                user.totalUniqueBalance -= removedBalance;
                user.totalUniqueComission -= removedBalance * getUserFee(utility, from);
                
                if (user.userNfts.length > 0) {
                    if (user.defaultUserFee > utils[utility].rewardFee)
                        totalEraData[era][1] += removedBalance * (user.defaultUserFee - utils[utility].rewardFee);
                } else {
                    totalEraData[era][0] -= removedBalance;
                    totalEraData[era][1] -= removedBalance * utils[utility].rewardFee;
                }
            } else {
                user.haveNft[utility] = false;    
                if (_removeNft(user.userNfts, utility)) {
                    uint256 removedBalance = nAstr.balanceOf(from);
                    totalEraData[era][0] -= removedBalance - user.totalUniqueBalance;
                    totalEraData[era][1] -= (removedBalance - user.totalUniqueBalance) * user.defaultUserFee;

                    uint8 rFee = LIQUIDSTAKING_FEE;
                    _updateWithUniquesAndPriorityFee(from, era, rFee);
                    _updateUserFee(user, rFee, era);

                } else {
                    uint8 minFee = _findMin(user);
                    if (minFee > user.defaultUserFee) {
                        totalEraData[era][1] += (nAstr.balanceOf(from) - user.totalUniqueBalance) * (minFee - user.defaultUserFee);

                        _updateWithUniquesAndPriorityFee(from, era, minFee);
                        _updateUserFee(user, minFee, era);
                    }
                }
            }
            return true;
        }
        return false;
    }

    /// @notice function to remove the user's nft utility from the array.
    /// @param nftList => user utilities array.
    /// @param utilName => name of utility to remove.
    /// @return noMoreNft => returns true if the array is now empty.
    /// @custom:defimoon-note we chose deletion through a pass through the entire array in a loop, 
    /// since many nft contracts (and utilities, respectively) are not planned
    function _removeNft(string[] storage nftList, string memory utilName) private returns (bool) {
        uint256 l = nftList.length;
        bytes32 utilNameHash = keccak256(abi.encodePacked(utilName))
        for (uint256 i; i < l; i++) {
            if (keccak256(abi.encodePacked(nftList[i])) == utilNameHash) {
                nftList[i] = nftList[l - 1];
                nftList.pop();
                break;
            }
        }
        return nftList.length == 0;
    }   

    /// @notice function to add nft utility to user.
    /// @param nftList => user utilities array.
    /// @param utilName => name of utility to add.
    /// @return didntHaveNftBefore => returns true if the user did not have utilities in the array before.
    function _addNft(string[] storage nftList, string memory utilName) private returns (bool) {
        nftList.push(utilName);
        return nftList.length <= 1;
    }

    /// @notice helper function for recalculating the user's commission.
    /// @param _user => user address.
    /// @param era => current era number.
    /// @param fee => fee for comparison.
    function _updateWithUniquesAndPriorityFee(address _user, uint256 era, uint8 fee) private {
        UserInfo storage user = users[_user];

        uint256 l = user.uniqueUserNfts.length;
        for (uint i; i < l; i++) {
            uint8 utilFee = utils[user.uniqueUserNfts[i]].rewardFee;
            uint8 minFee = fee > utilFee ? utilFee : fee;
            if (minFee > user.defaultUserFee) {
                uint256 toAdd = distr.getUserDntBalanceInUtil(_user, user.uniqueUserNfts[i], dntName) * (minFee - user.defaultUserFee);
                totalEraData[era][1] += toAdd;
                user.totalUniqueComission += toAdd;
            }
        }
    }

    /// @notice helper function for recalculating the user's commission.
    /// @param _user => user address.
    /// @param newFee => new user fee value.
    /// @param useUtilFee => flag responsible for the method of choosing a fee for comparison.
    ///     true - user <util.rewardFee>
    function _updateWithUniques(address _user, uint8 newFee, bool useUtilFee) private {
        UserInfo storage user = users[_user];
        uint256 era = liquidStaking.currentEra();

        uint256 l = user.uniqueUserNfts.length;
        for (uint i; i < l; i++) {
            uint8 oldFee = useUtilFee ? utils[user.uniqueUserNfts[i]].rewardFee : getUserFee(user.uniqueUserNfts[i], _user);

            if (oldFee > newFee) {
                uint256 toSub = distr.getUserDntBalanceInUtil(_user, user.uniqueUserNfts[i], dntName) * (oldFee - newFee);
                totalEraData[era][1] -= toSub;
                user.totalUniqueComission -= toSub;
            }
        }
    }

    /// @notice function for redistribution of balances and fees for the user when transferring DNT tokens.
    /// @param utility => utility name.
    /// @param from => sender's address. equals <address(0)> at mint.
    /// @param to => address of the recipient. equals <address(0)> at burn.
    /// @param amount => amount of sended DNT tokens.
    function _transferDnt(string memory utility, address from, address to, uint256 amount) private {
        require(amount > 0, "Incorrect amount");
        if (from == to) return;

        Utility storage util_ = utils[utility];

        uint256 utilAmountBefore = util_.totalAmount;

        if (to != address(0)) {
            if (_addDntToUser(utility, to, amount)) {
                util_.totalAmount += amount;
                _updateUserBalance(utility, to, distr.getUserDntBalanceInUtil(to, utility, dntName));
            }
        }

        if (from != address(0)) {
            if (_removeDntFromUser(utility, from, amount)) {
                util_.totalAmount -= amount;
                _updateUserBalance(utility, from, distr.getUserDntBalanceInUtil(from, utility, dntName));
            }
        }

        if (util_.totalAmount != utilAmountBefore) _updateTotalBalance(utility, util_.totalAmount);

    }
    
    /// @notice function for redistribution of balances and fees for the user when adding DNT tokens to user.
    /// @param utility => utility name.
    /// @param to => address of the recipient.
    /// @param amount => amount of removing DNT tokens;
    /// @return userHasUtility => returns true if the user has the given utility.
    function _addDntToUser(string memory utility, address to, uint256 amount) private returns (bool) {
        UserInfo storage user = users[to];

        uint256 era = liquidStaking.currentEra();
        uint8 fee;

        if (user.haveUniqueNft[utility]) {  
            fee = getUserFee(utility, to);

            user.totalUniqueBalance += amount;
            user.totalUniqueComission += amount * fee;

        } else if (user.userNfts.length > 0) {
            fee = user.defaultUserFee;
        } else return false;

        totalEraData[era][0] += amount;
        totalEraData[era][1] += amount * fee;

        return user.haveNft[utility] || user.haveUniqueNft[utility];
    }

    /// @notice function for redistribution of balances and fees for the user when removing DNT tokens to user.
    /// @param utility => utility name.
    /// @param from => sender's address.
    /// @param amount => amount of removing DNT tokens;
    /// @return userHasUtility => returns true if the user has the given utility.
    function _removeDntFromUser(string memory utility, address from, uint256 amount) private returns (bool) {
        UserInfo storage user = users[from];

        uint256 era = liquidStaking.currentEra();
        uint8 fee;

        if (user.haveUniqueNft[utility]) {
            fee = getUserFee(utility, from);
            
            user.totalUniqueBalance -= amount;
            user.totalUniqueComission -= amount * fee;
        } else if (user.userNfts.length > 0) {
            fee = user.defaultUserFee;
        } else return false;

        totalEraData[era][0] -= amount;
        totalEraData[era][1] -= amount * fee;

        return user.haveNft[utility] || user.haveUniqueNft[utility];
    }

    /// @notice function to update on balance values in the utility.
    /// @param utility => utility name.
    /// @param balance => current balance in utility.
    function _updateTotalBalance(string memory utility, uint256 balance) private {
        uint256 era = liquidStaking.currentEra();

        _updateUtility(utility, era);

        isZeroData[era] = totalEraData[era][0] > 0 ? false : true;

        utils[utility].totalEraAmount[era] = balance;
        utils[utility].isZeroAmount[era] = balance > 0 ? false : true;
    }

    /// @notice function to update <util.totalEraAmount> to the current moment.
    /// @param utility => utility name.
    /// @param era => current era number.
    function _updateUtility(string memory utility, uint256 era) private {
        Utility storage util = utils[utility];

        uint256 updEra = util.updatedEra;
        if (era > updEra) {
            util.totalEraAmount[era] = util.totalEraAmount[updEra];
            util.isZeroAmount[era] = util.isZeroAmount[updEra];
            util.updatedEra = era;
        }
    }

    /// @notice function to update <user.eraAmount> to the current moment.
    /// @param utility => utility name.
    /// @param _user => user address.
    /// @param balance => current user balance in utility.
    function _updateUserBalance(string memory utility, address _user, uint256 balance) private {
        uint256 era = liquidStaking.currentEra();

        User storage user = utils[utility].users[_user];

        user.eraAmount[era] = balance;
        user.isZeroAmount[era] = balance > 0 ? false : true;
    }

    /// @notice function to search for the minimum fee among all default utilities of the user.
    /// @param user => <UserInfo struct> by user.
    /// @return min => min user default fee.
    function _findMin(UserInfo storage user) private view returns (uint8 min) {
        min = LIQUIDSTAKING_FEE;

        uint256 l = user.userNfts.length;
        for (uint256 i; i < l; i++) {
            if (utils[user.userNfts[i]].rewardFee < min) 
                min = utils[user.userNfts[i]].rewardFee;
        }
    }

    function _updateUserFee(UserInfo storage user, uint8 fee, uint256 era) private {
        user.defaultUserFee = fee;
        user.eraDefaultUserFee[era] = fee;
    }

    // --------------------------------------------------------------------
    // View functions // --------------------------------------------------
    // --------------------------------------------------------------------

    function getEra(uint256 era) external view returns (uint256[2] memory) {
        return totalEraData[era];
    }

    function _getEraData(uint256 era) private returns (uint256[2] memory) {
        if (totalEraData[era + 1][0] == 0 && !isZeroData[era + 1])
            totalEraData[era + 1] = totalEraData[era];

        return totalEraData[era];
    }

    function getUserEraFee(address user, uint256 era) external view returns (uint8) {
        return users[user].eraDefaultUserFee[era];
    }

    function getDefaultUserFee(address _user) public view returns (uint8) {
        return users[_user].defaultUserFee > 0 ? users[_user].defaultUserFee : LIQUIDSTAKING_FEE;
    }

    function getUserFee(string memory utility, address _user) public view returns (uint8) {
        uint8 _defaultFee = getDefaultUserFee(_user);
        if (!utils[utility].isUnique) return _defaultFee;

        return getBestUtilFee(utility, _defaultFee);
    }

    function getBestUtilFee(string memory utility, uint8 fee) public view returns (uint8) {
        uint8 utilFee = utils[utility].rewardFee > 0 ? utils[utility].rewardFee : LIQUIDSTAKING_FEE;
        if (utilFee > fee) return fee;
        return utilFee;
    }

    function getUserEraBalance(string memory utility, address _user, uint256 era) external view returns (uint256, bool) {
        return (utils[utility].users[_user].eraAmount[era], utils[utility].users[_user].isZeroAmount[era]);
    }

    function isUnique(string memory utility) external view returns (bool) {
        return utils[utility].isUnique;
    }

    // *
    // the functions below are currently only used for tests, but may be used in the future
    // *

    function getUserEraAmount(string memory _util, address _user, uint256 _era) external view returns (uint256, bool) {
        return (utils[_util].users[_user].eraAmount[_era], utils[_util].users[_user].isZeroAmount[_era]);
    }

    function getUserInfo(address _user) external view returns (uint8, uint256, uint256) {
        return (users[_user].defaultUserFee, users[_user].totalUniqueBalance, users[_user].totalUniqueComission);
    }

    function getUserNfts(address _user) external view returns (string[] memory, string[] memory) {
        return (users[_user].uniqueUserNfts, users[_user].userNfts);
    }

    function getEraAmount(uint256 _era) external view returns (uint256[2] memory, bool, uint256) {
        return (totalEraData[_era], isZeroData[_era], updatedEra);
    }

    function getUtilAmount(string memory _util, uint256 _era) external view returns (uint256, uint256, bool, uint256) {
        return (utils[_util].totalAmount, utils[_util].totalEraAmount[_era], utils[_util].isZeroAmount[_era], utils[_util].updatedEra);
    }

    function getUtilsList() external view returns (string[] memory) {
        return utilsList;
    }
}
