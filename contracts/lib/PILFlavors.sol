// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IPILicenseTemplate, PILTerms } from "../interfaces/modules/licensing/IPILicenseTemplate.sol";

/// @title PILFlavors Library
/// @notice Provides a set of predefined PILTerms configurations for different licensing scenarios
/// See the text: https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf
library PILFlavors {
    bytes public constant EMPTY_BYTES = "";

    /// @notice Gets the default values of PIL terms
    function defaultValuesLicenseTerms() internal pure returns (PILTerms memory) {
        return _defaultPIL();
    }

    /// @notice Helper method to get licenseTermsId for the defaultValuesLicenseTerms() configuration
    /// @param pilTemplate The address of the PILicenseTemplate
    /// @return The licenseTermsId for the defaultValuesLicenseTerms() configuration, 0 if not registered
    function getDefaultValuesLicenseTermsId(IPILicenseTemplate pilTemplate) internal view returns (uint256) {
        return pilTemplate.getLicenseTermsId(_defaultPIL());
    }

    /// @notice Gets the values to create a Non Commercial Social Remix licenseTerms flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-1-non-commercial-social-remixing
    /// @return The input struct for PILicenseTemplate.registerLicenseTerms()
    function nonCommercialSocialRemixing() internal returns (PILTerms memory) {
        return _nonComSocialRemixingPIL();
    }

    /// @notice Helper method to get the licenseTermsId for the nonCommercialSocialRemixing() configuration
    /// @param pilTemplate The address of the PILicenseTemplate
    /// @return The licenseTermsId for the nonCommercialSocialRemixing() configuration, 0 if not registered
    function getNonCommercialSocialRemixingId(IPILicenseTemplate pilTemplate) internal view returns (uint256) {
        return pilTemplate.getLicenseTermsId(_nonComSocialRemixingPIL());
    }

    /// @notice Gets the values to create a Non Commercial Social Remix licenseTerms flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-2-commercial-use
    /// @param mintingFee The fee to be paid when minting a license, in the smallest unit of the token
    /// @param currencyToken The token to be used to pay the minting fee
    /// @param royaltyPolicy The address of the royalty licenseTerms to be used by the license template.
    /// @return The input struct for PILicenseTemplate.registerLicenseTerms()
    function commercialUse(
        uint256 mintingFee,
        address currencyToken,
        address royaltyPolicy
    ) internal returns (PILTerms memory) {
        return _commercialUsePIL(mintingFee, currencyToken, royaltyPolicy);
    }

    /// @notice Helper method to get the licenseTermsId for the commercialUse() configuration
    /// @param mintingFee The fee to be paid when minting a license, in the smallest unit of the token
    /// @param currencyToken The token to be used to pay the minting fee
    /// @return The licenseTermsId for the commercialUse() configuration, 0 if not registered
    function getCommercialUseId(
        IPILicenseTemplate pilTemplate,
        uint256 mintingFee,
        address currencyToken,
        address royaltyPolicy
    ) internal view returns (uint256) {
        return pilTemplate.getLicenseTermsId(_commercialUsePIL(mintingFee, currencyToken, royaltyPolicy));
    }

    /// @notice Gets the values to create a Commercial Remixing licenseTerms flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-3-commercial-remix
    /// @param commercialRevShare The percentage of the revenue that the commercializer will share
    /// with the parent creator, with 1 decimal (e.g. 10 means 1%)
    /// @param royaltyPolicy The address of the royalty policy to be used by the license template.
    /// @return The input struct for PILicenseTemplate.registerLicenseTerms()
    function commercialRemix(
        uint256 mintingFee,
        uint32 commercialRevShare,
        address royaltyPolicy,
        address currencyToken
    ) internal pure returns (PILTerms memory) {
        return _commercialRemixPIL(mintingFee, commercialRevShare, royaltyPolicy, currencyToken);
    }

    /// @notice Helper method to get the licenseTermsId for the commercialRemix() configuration from LicensingModule
    /// @param pilTemplate The address of the PILicenseTemplate
    /// @param commercialRevShare The percentage of the revenue that the commercializer will share with the
    /// parent creator, with 1 decimal (e.g. 10 means 1%)
    /// @param royaltyPolicy The address of the royalty policy to be used by the license template.
    /// @return The licenseTermsId for the commercialRemix() configuration, 0 if not registered
    function getCommercialRemixId(
        IPILicenseTemplate pilTemplate,
        uint256 mintingFee,
        uint32 commercialRevShare,
        address royaltyPolicy,
        address currencyToken
    ) internal view returns (uint256) {
        return
            pilTemplate.getLicenseTermsId(
                _commercialRemixPIL(mintingFee, commercialRevShare, royaltyPolicy, currencyToken)
            );
    }

    /// @notice Gets the default values of PIL terms
    function _defaultPIL() private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: address(0),
                defaultMintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                commercialRevCeiling: 0,
                derivativesAllowed: false,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCeiling: 0,
                currency: address(0),
                uri: ""
            });
    }

    /// @notice Gets the values to create a Non Commercial Social Remix licenseTerms flavor
    function _nonComSocialRemixingPIL() private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: address(0),
                defaultMintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: address(0),
                uri: ""
            });
    }

    /// @notice Gets the values to create a Commercial Use licenseTerms flavor
    function _commercialUsePIL(
        uint256 mintingFee,
        address currencyToken,
        address royaltyPolicy
    ) private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCeiling: 0,
                currency: currencyToken,
                uri: ""
            });
    }

    /// @notice Gets the values to create a Commercial Remixing licenseTerms flavor
    function _commercialRemixPIL(
        uint256 mintingFee,
        uint32 commercialRevShare,
        address royaltyPolicy,
        address currencyToken
    ) private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: commercialRevShare,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCeiling: 0,
                currency: currencyToken,
                uri: ""
            });
    }
}
