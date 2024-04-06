// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { RegisterPILPolicyParams, PILPolicy } from "../interfaces/modules/licensing/IPILPolicyFrameworkManager.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "./Licensing.sol";

/// @title PILFlavors Library
/// @notice Provides a set of predefined PILPolicy configurations for different licensing scenarios
/// See the text: https://github.com/storyprotocol/protocol-core/blob/main/PIL-Beta-2024-02.pdf
library PILFlavors {
    bytes public constant EMPTY_BYTES = "";

    /// @notice Gets the default values of Licensing.Policy + Policy Framework Manager
    function defaultValuesPolicy() internal pure returns (RegisterPILPolicyParams memory) {
        PILPolicy memory policy = _defaultPIL();
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: _defaultPIL()
            });
    }

    /// @notice Helper method to get the policyId for the defaultValuesPolicy() configuration from LicensingModule
    /// @param module The LicensingModule contract
    /// @param pilFramework The address of the PILPolicyFrameworkManager
    /// @return The policyId for the defaultValuesPolicy() configuration, 0 if not registered
    function getDefaultValuesPolicyId(ILicensingModule module, address pilFramework) internal view returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(_defaultPIL()),
            royaltyPolicy: address(0),
            royaltyData: abi.encode(uint256(0)),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return module.getPolicyId(policy);
    }

    /// @notice Gets the values to create a Non Commercial Social Remix policy flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-1-non-commercial-social-remixing
    /// @return The input struct for PILPolicyFrameworkManager.registerPILPolicy()
    function nonCommercialSocialRemixing() internal returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: _nonComSocialRemixingPIL()
            });
    }

    /// @notice Helper method to get the policyId for the nonCommercialSocialRemixing() configuration
    /// from LicensingModule
    /// @param module The LicensingModule contract
    /// @param pilFramework The address of the PILPolicyFrameworkManager
    /// @return The policyId for the nonCommercialSocialRemixing() configuration, 0 if not registered
    function getNonCommercialSocialRemixingId(
        ILicensingModule module,
        address pilFramework
    ) internal view returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(_nonComSocialRemixingPIL()),
            royaltyPolicy: address(0),
            royaltyData: abi.encode(uint256(0)),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return module.getPolicyId(policy);
    }

    /// @notice Gets the values to create a Non Commercial Social Remix policy flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-2-commercial-use
    /// @param mintingFee The fee to be paid when minting a license, in the smallest unit of the token
    /// @param mintingFeeToken The token to be used to pay the minting fee
    /// @param royaltyPolicy The address of the royalty policy to be used by the policy framework.
    /// @return The input struct for PILPolicyFrameworkManager.registerPILPolicy()
    function commercialUse(
        uint256 mintingFee,
        address mintingFeeToken,
        address royaltyPolicy
    ) internal returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                mintingFee: mintingFee,
                mintingFeeToken: mintingFeeToken,
                policy: _commercialUsePIL()
            });
    }

    /// @notice Helper method to get the policyId for the commercialUse() configuration from LicensingModule
    /// @param module The LicensingModule contract
    /// @param pilFramework The address of the PILPolicyFrameworkManager
    /// @param mintingFee The fee to be paid when minting a license, in the smallest unit of the token
    /// @param mintingFeeToken The token to be used to pay the minting fee
    /// @return The policyId for the commercialUse() configuration, 0 if not registered
    function getCommercialUseId(
        ILicensingModule module,
        address pilFramework,
        uint256 mintingFee,
        address mintingFeeToken,
        address royaltyPolicy
    ) internal view returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(_commercialUsePIL()),
            royaltyPolicy: royaltyPolicy,
            royaltyData: abi.encode(uint32(0)),
            mintingFee: mintingFee,
            mintingFeeToken: mintingFeeToken
        });
        return module.getPolicyId(policy);
    }

    /// @notice Gets the values to create a Commercial Remixing policy flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-3-commercial-remix
    /// @param commercialRevShare The percentage of the revenue that the commercializer will share
    /// with the parent creator, with 1 decimal (e.g. 10 means 1%)
    /// @param royaltyPolicy The address of the royalty policy to be used by the policy framework.
    /// @return The input struct for PILPolicyFrameworkManager.registerPILPolicy()
    function commercialRemix(
        uint32 commercialRevShare,
        address royaltyPolicy
    ) internal pure returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: _commercialRemixPIL(commercialRevShare)
            });
    }

    /// @notice Helper method to get the policyId for the commercialRemix() configuration from LicensingModule
    /// @param module The LicensingModule contract
    /// @param pilFramework The address of the PILPolicyFrameworkManager
    /// @param commercialRevShare The percentage of the revenue that the commercializer will share with the
    /// parent creator, with 1 decimal (e.g. 10 means 1%)
    /// @param royaltyPolicy The address of the royalty policy to be used by the policy framework.
    /// @return The policyId for the commercialRemix() configuration, 0 if not registered
    function getcommercialRemixId(
        ILicensingModule module,
        address pilFramework,
        uint32 commercialRevShare,
        address royaltyPolicy
    ) internal view returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(_commercialRemixPIL(commercialRevShare)),
            royaltyPolicy: royaltyPolicy,
            royaltyData: abi.encode(commercialRevShare),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return module.getPolicyId(policy);
    }

    /// @notice Gets the default values of PILPolicy
    function _defaultPIL() private pure returns (PILPolicy memory) {
        return
            PILPolicy({
                attribution: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                derivativesAllowed: false,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            });
    }

    /// @notice Gets the values to create a Non Commercial Social Remix policy flavor
    function _nonComSocialRemixingPIL() private pure returns (PILPolicy memory) {
        return
            PILPolicy({
                attribution: true,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            });
    }

    /// @notice Gets the values to create a Commercial Use policy flavor
    function _commercialUsePIL() private pure returns (PILPolicy memory) {
        return
            PILPolicy({
                attribution: true,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            });
    }

    /// @notice Gets the values to create a Commercial Remixing policy flavor
    function _commercialRemixPIL(uint32 commercialRevShare) private pure returns (PILPolicy memory) {
        return
            PILPolicy({
                attribution: true,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: commercialRevShare,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            });
    }
}
