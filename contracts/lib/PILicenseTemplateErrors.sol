// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title PILicenseTemplate Errors Library
/// @notice Library for all PILicenseTemplate related contract errors.
library PILicenseTemplateErrors {
    ////////////////////////////////////////////////////////////////////////////
    //                         PILicenseTemplate                      //
    ////////////////////////////////////////////////////////////////////////////

    error PILicenseTemplate__CommercialDisabled_CantAddCommercializers();
    error PILicenseTemplate__CommercializerCheckerDoesNotSupportHook(address checker);
    error PILicenseTemplate__RoyaltyPolicyNotWhitelisted();
    error PILicenseTemplate__CurrencyTokenNotWhitelisted();
    error PILicenseTemplate__RoyaltyPolicyRequiresCurrencyToken();
    error PILicenseTemplate__CommercialDisabled_CantAddAttribution();
    error PILicenseTemplate__CommercialDisabled_CantAddRevShare();
    error PILicenseTemplate__DerivativesDisabled_CantAddAttribution();
    error PILicenseTemplate__DerivativesDisabled_CantAddApproval();
    error PILicenseTemplate__DerivativesDisabled_CantAddReciprocal();
    error PILicenseTemplate__LicenseTermsNotFound();
    error PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy();
    error PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired();
    error PILicenseTemplate__ReciprocalButDifferentPolicyIds();
    error PILicenseTemplate__ReciprocalValueMismatch();
    error PILicenseTemplate__CommercialValueMismatch();
    error PILicenseTemplate__StringArrayMismatch();
    error PILicenseTemplate__CommercialDisabled_CantAddMintingFee();
    error PILicenseTemplate__CommercialDisabled_CantAddMintingFeeToken();
}
