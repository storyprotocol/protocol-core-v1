// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Licensing
/// @notice Types and constants used by the licensing related contracts
library Licensing {
    /// @notice A particular configuration (flavor) of a Policy Framework, setting values for the licensing
    /// terms (parameters) of the framework.
    /// @param isLicenseTransferable Whether or not the license is transferable
    /// @param policyFramework address of the IPolicyFrameworkManager this policy is based on
    /// @param frameworkData Data to be used by the policy framework to verify minting and linking
    /// @param royaltyPolicy address of the royalty policy to be used by the policy framework, if any
    /// @param royaltyData Data to be used by the royalty policy (for example, encoding of the royalty percentage)
    /// @param mintingFee Fee to be paid when minting a license
    /// @param mintingFeeToken Token to be used to pay the minting fee
    // TODO: the struct will not be used in mainnet.  will remove.
    struct Policy {
        bool isLicenseTransferable;
        address policyFramework;
        bytes frameworkData;
        address royaltyPolicy;
        bytes royaltyData;
        uint256 mintingFee;
        address mintingFeeToken;
    }

    /// @notice Data that define a License Agreement NFT
    /// @param policyId Id of the policy this license is based on, which will be set in the derivative IP when the
    /// license is burnt for linking
    /// @param licensorIpId Id of the IP this license is for
    /// @param transferable Whether or not the license is transferable
    // TODO: the struct will not be used in mainnet.  will remove.
    struct License {
        uint256 policyId;
        address licensorIpId;
        bool transferable;
        // TODO: support for transfer hooks
    }

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
