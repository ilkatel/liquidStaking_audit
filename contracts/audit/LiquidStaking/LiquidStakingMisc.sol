// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./LiquidStakingStorage.sol";

contract LiquidStakingMisc is AccessControlUpgradeable, LiquidStakingStorage {
    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;
    
    /// @notice add new partner dapp
    /// @param _utility => dapp utility name
    /// @param _dapp => dapp address
    function addDapp(string memory _utility, address _dapp) external onlyRole(MANAGER) {
        require(_dapp != address(0), "Incorrect dapp address");
        require(!haveUtility[_utility], "Utility already added");

        distr.addUtility(_utility);
        dappsList.push(_utility);
        haveUtility[_utility] = true;
        isActive[_utility] = true;
        dapps[_utility].dappAddress = _dapp;
    }
    
    /// @notice activate or deactivate interaction with dapp
    /// @param _utility => dapp utility name
    /// @param _state => state variable
    function setDappStatus(string memory _utility, bool _state) external onlyRole(MANAGER) {
        require(haveUtility[_utility], "No such this utility");
        isActive[_utility] = _state;
        if (!_state) {
            // set deactivation era
            // if dapp is not active - cant stake, but can unstake and withdraw
            deactivationEra[_utility] = currentEra() + withdrawBlock;
        }
    }

    /// @notice return users rewards
    /// @param _user => user address
    function getUserRewards(address _user) public view returns (uint) {
        return totalUserRewards[_user];
    }

    /// @notice returns user active withdrawals
    function getUserWithdrawals() external view returns (Withdrawal[] memory) {
        return withdrawals[msg.sender];
    }

    /// @notice sets min stake amount
    /// @param _amount => new min stake amount
    function setMinStakeAmount(uint _amount) public onlyRole(MANAGER) {
        require(_amount > 0, "Should be greater than zero!");
        minStakeAmount = _amount;
        emit SetMinStakeAmount(msg.sender, _amount);
    }
    
    /*
    /// @notice manually fill the unbonded pool
    function fillUnbonded() external payable {
        require(msg.value > 0, "Provide some value!");
        unbondedPool += msg.value;

        emit FillUnbonded(msg.sender, msg.value);
    }

    /// @notice utility func for filling reward pool manually
    function fillRewardPool() external payable {
        require(msg.value > 0, "Provide some value!");
        rewardPool += msg.value;

        emit FillRewardPool(msg.sender, msg.value);
    }

    /// @notice manually fill the unstaking pool
    function fillUnstaking() external payable {
        require(msg.value > 0, "Provide some value!");
        unstakingPool += msg.value;

        emit FillUnstaking(msg.sender, msg.value);
    }

    /// @notice withdraw revenu function
    function withdrawRevenue(uint _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(totalRevenue >= _amount, "Not enough funds in revenue pool");
        totalRevenue -= _amount;
        payable(msg.sender).sendValue(_amount);

        emit WithdrawRevenue(_amount);
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

    /// @notice disabled revoke ownership functionality
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
    */
}
