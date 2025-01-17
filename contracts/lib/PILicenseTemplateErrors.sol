// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title PILicenseTemplate Errors Library
/// @notice Library for all PILicenseTemplate related contract errors.
library PILicenseTemplateErrors {
    /// @notice Zero address provided for Access Manager at initialization.
    error PILicenseTemplate__ZeroAccessManager();

    /// @notice Cannot add commercializers when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddCommercializers();

    /// @notice Provided commercializer does not support IHookModule.
    error PILicenseTemplate__CommercializerCheckerDoesNotSupportHook(address checker);

    /// @notice PIL terms royalty policy is not whitelisted by the Royalty Module.
    error PILicenseTemplate__RoyaltyPolicyNotWhitelisted();

    /// @notice PIL terms currency token is not whitelisted by the Royalty Module.
    error PILicenseTemplate__CurrencyTokenNotWhitelisted();

    /// @notice Royalty policy requires a currency token.
    error PILicenseTemplate__RoyaltyPolicyRequiresCurrencyToken();

    /// @notice Cannot add commercial attribution when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddAttribution();

    /// @notice Cannot add commercial revenue share when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddRevShare();

    /// @notice Cannot add commercial royalty policy when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy();

    /// @notice Cannot add commercial revenue ceiling when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddRevCeiling();

    /// @notice Cannot add derivative rev ceiling share when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddDerivativeRevCeiling();

    /// @notice Royalty policy is required when commercial use is enabled.
    error PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired();

    /// @notice Cannot add derivative attribution when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddAttribution();

    /// @notice Cannot add derivative approval when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddApproval();

    /// @notice Cannot add derivative reciprocal when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddReciprocal();

    /// @notice Cannot add derivative revenue ceiling when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddDerivativeRevCeiling();

    /// @notice Zero address provided for License Registry at initialization.
    error PILicenseTemplate__ZeroLicenseRegistry();

    /// @notice Zero address provided for Royalty Module at initialization.
    error PILicenseTemplate__ZeroRoyaltyModule();
}
