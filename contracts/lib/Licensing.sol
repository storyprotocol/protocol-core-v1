// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Licensing
/// @notice Types and constants used by the licensing related contracts
library Licensing {
    /// @notice This struct is used by IP owners to define the configuration
    /// when others are minting license tokens of their IP through the LicensingModule.
    /// When the `mintLicenseTokens` function of LicensingModule is called, the LicensingModule will read
    /// this configuration to determine the minting fee and who can receive the license tokens.
    /// IP owners can set these configurations for each License or set the configuration for the IP
    /// so that the configuration applies to all licenses of the IP.
    /// If both the license and IP have the configuration, then the license configuration takes precedence.
    /// @param isSet Whether the configuration is set or not.
    /// @param mintingFee The minting fee to be paid when minting license tokens.
    /// @param mintingFeeModule The module that determines the minting fee.
    /// @param receiverCheckModule The module that determines who can receive the license tokens.
    /// @param receiverCheckData The data to be used by the receiver check module.
    struct MintingLicenseConfig {
        bool isSet;
        uint256 mintingFee;
        address mintingFeeModule;
        address receiverCheckModule;
        bytes receiverCheckData;
    }
}
