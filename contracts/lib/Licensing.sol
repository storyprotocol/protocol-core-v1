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
    struct License {
        uint256 policyId;
        address licensorIpId;
        bool transferable;
        // TODO: support for transfer hooks
    }

    struct MintingLicenseSpec {
        bool isSet;
        uint256 mintingFee;
        address mintingFeeModule;
        address receiverCheckModule;
        bytes receiverCheckData;
    }
}
