//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./LiquidStakingStorage.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "./interfaces/ILiquidStakingManager.sol";

contract LiquidStaking is AccessControlUpgradeable, LiquidStakingStorage, Proxy {
    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _DNTname,
        string memory _utilName,
        address _distrAddr
    ) public initializer {
        require(_distrAddr.isContract(), "_distrAddr should be contract address");
        DNTname = _DNTname;
        utilName = _utilName;

        uint256 era = currentEra() - 1;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER, msg.sender);
        setMinStakeAmount(10);
        withdrawBlock = DAPPS_STAKING.read_unbonding_period();

        distr = NDistributor(_distrAddr);

        lastUpdated = era;
        lastStaked = era;
        lastUnstaked = era;
        lastClaimed = era;

        dappsList.push(_dntUtil);
        haveUtility[_dntUtil] = true;
        isActive[_dntUtil] = true;
        dapps[_dntUtil].dappAddress = address(this);
    }

    function initialize2(address _nftDistr, address _adaptersDistr) external onlyRole(MANAGER) {
        nftDistr = INFTDistributor(_nftDistr);
        adaptersDistr = IAdaptersDistributor(_adaptersDistr);

        _grantRole(MANAGER, _nftDistr);
        _grantRole(MANAGER, _adaptersDistr);

        dapps[utilName].sum2unstake = sum2unstake;
        dapps[utilName].stakedBalance = distr.totalDntInUtil(utilName); 
        lastEraTotalBalance = distr.totalDnt(DNTname);
    }

    function setLiquidStakingManager(address _liquidStakingManager) external onlyRole(MANAGER) {
        require(_liquidStakingManager != address(0), "Address cant be null");
        require(_liquidStakingManager.isContract(), "Manager should be contract!");
        liquidStakingManager = _liquidStakingManager;
    }

    function _implementation() internal view override returns (address) {
        /// @dev address(0) should changed on LiquidStakingManager contract address
        return ILiquidStakingManager(liquidStakingManager).getAddress(msg.sig);
    }

    // --------------------------------------------------------------------
    // Mock functions // Functions for tests only -------------------------
    // --------------------------------------------------------------------

    /// @notice function for tests
    function setting() external onlyRole(MANAGER) {
        DAPPS_STAKING.set_reward_destination(DappsStaking.RewardDestination.FreeBalance);
    }
}   
