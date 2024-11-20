// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Licensing
/// @notice Types and constants used by the licensing related contracts
library Licensing {
    /// @notice This struct is used by IP owners to define the configuration
    /// when others are minting license tokens of their IP through the LicensingModule.
    /// When the `mintLicenseTokens` function of LicensingModule is called, the LicensingModule will read
    /// this configuration to determine the minting fee and execute the licensing hook if set.
    /// IP owners can set these configurations for each License or set the configuration for the IP
    /// so that the configuration applies to all licenses of the IP.
    /// If both the license and IP have the configuration, then the license configuration takes precedence.
    /// @param isSet Whether the configuration is set or not.
    /// @param mintingFee The minting fee to be paid when minting license tokens.
    /// @param licensingHook  The hook contract address for the licensing module, or address(0) if none
    /// @param hookData The data to be used by the licensing hook.
    /// @param commercialRevShare The commercial revenue share percentage.
    /// @param disabled Whether the license is disabled or not.
    /// @param expectMinimumGroupRewardShare The minimum percentage of the group’s reward share
    /// (from 0 to 100%, represented as 100 * 10 ** 6) that can be allocated to the IP when it is added to the group.
    /// If the remaining reward share in the group is less than the minimumGroupRewardShare,
    /// the IP cannot be added to the group.
    /// @param expectGroupRewardPool The address of the expected group reward pool.
    /// The IP can only be added to a group with this specified reward pool address,
    /// or address(0) if the IP does not want to be added to any group.
    struct LicensingConfig {
        bool isSet;
        uint256 mintingFee;
        address licensingHook;
        bytes hookData;
        uint32 commercialRevShare;
        bool disabled;
        uint32 expectMinimumGroupRewardShare;
        address expectGroupRewardPool;
    }
}
