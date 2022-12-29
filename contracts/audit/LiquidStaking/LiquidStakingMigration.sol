// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./LiquidStakingStorage.sol";

contract LiquidStakingMigration is AccessControlUpgradeable, LiquidStakingStorage {
    using AddressUpgradeable for address payable;
    using AddressUpgradeable for address;

    // --------------------------------------------------------------------
    // Misk 1 -> 1.5 // Will removed with next proxy update ---------------
    // Functions for a smooth transition from handlers to adapters --------
    // --------------------------------------------------------------------
    
    /// @notice iterate by each partner address and get user rewards from handlers
    /// @param _user shows share of user in nTokens
    function getUserLpTokens(address _user) public view returns (uint amount) {
        if (partners.length == 0) return 0;
        for (uint i; i < partners.length; i++) {
            amount += IPartnerHandler(partners[i]).calc(_user);
        }
    }
    
    /// @notice sorts the list in ascending order and return mean
    /// @param _arr array with user's shares
    function findMedian(uint[] memory _arr) private pure returns (uint mean) {
        uint[] memory arr = _arr;
        uint len = arr.length;
        bool swapped = false;
        for (uint i; i < len - 1; i++) {
            for (uint j; j < len - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    swapped = true;
                    uint s = arr[j + 1];
                    arr[j + 1] = arr[j];
                    arr[j] = s;
                }
            }
            if (!swapped) {
                return arr[len/2];
            }
        }
        if (len % 2 == 0) return (arr[len/2] + arr[len/2 - 1])/2;
        return arr[len/2];
    }

    /// @notice saving information about users balances
    /// @param _user user's address
    function eraShot(address _user) external onlyRole(MANAGER) {
        require(_user != address(0), "Zero address alarm!");        
        
        uint era = currentEra();
        require(usersShotsPerEra[_user][era].length <= eraShotsLimit, "Too much era shots");

        // checks if _user haven't shots in era yet
        if (usersShotsPerEra[_user][era].length == 0) {
            uint[] memory arr = usersShotsPerEra[_user][era - 1];

            if (arr.length > 0) {
                uint256 _amount = findMedian(arr);

                Staker storage staker = dapps["AdaptersUtility"].stakers[_user];    
                staker.eraBalance[era] += _amount;

                if (staker.eraBalance[era] == 0) {
                    staker.isZeroBalance[era] = true;
                } else {
                    staker.isZeroBalance[era] = false;
                }   
                
                if (dapps["AdaptersUtility"].stakers[_user].lastClaimedEra == 0) {
                    dapps["AdaptersUtility"].stakers[_user].lastClaimedEra = era + 1;
                }
            }
        }

        uint lpBal = getUserLpTokens(_user);
        usersShotsPerEra[_user][era].push(lpBal);
    }

    // --------------------------------------------------------------------
    // Migration // Function to migrate values from buffer ----------------
    // --------------------------------------------------------------------

    /// @notice function for migrating users storage
    /// @param _user => user address
    /// @dev the beginning of the migration must be carried out at the beginning of a new era
    /// @dev before starting the migration, you must first call eraShot 
    ///      for each user to calculate his rewards for the past era
    /// @dev before starting the migration, you need to make a claim of 
    ///      rewards for all past eras and call the sync function for all non-updated eras
    function migrateStorage(address _user) public onlyRole(MANAGER) {
        if (_user == address(0)) return;

        uint256 _era = currentEra();
        dapps[utilName].stakers[_user].rewards = totalUserRewards[_user];
        dapps[utilName].stakers[_user].eraBalance[_era] = distr.getUserDntBalanceInUtil(_user, utilName, DNTname) - buffer[_user][_era];
        dapps[utilName].stakers[_user].isZeroBalance[_era] = dapps[utilName].stakers[_user].eraBalance[_era] == 0 ? true : false;
        dapps[utilName].stakers[_user].eraBalance[_era + 1] = distr.getUserDntBalanceInUtil(_user, utilName, DNTname) - buffer[_user][_era + 1];
        dapps[utilName].stakers[_user].isZeroBalance[_era + 1] = dapps[utilName].stakers[_user].eraBalance[_era + 1] == 0 ? true : false;
        dapps[utilName].stakers[_user].lastClaimedEra = _era;
    }

}
