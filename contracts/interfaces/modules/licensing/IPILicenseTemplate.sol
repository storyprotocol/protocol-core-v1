// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ILicenseTemplate } from "../../../interfaces/modules/licensing/ILicenseTemplate.sol";

/// @notice This struct defines the terms for a Programmable IP License (PIL).
/// These terms can be attached to IP Assets. The legal document of the PIL can be found in this repository.
/// @param transferable Indicates whether the license is transferable or not.
/// @param royaltyPolicy The address of the royalty policy contract which required to StoryProtocol in advance.
/// @param mintingFee The fee to be paid when minting a license.
/// @param expiration The expiration period of the license.
/// @param commercialUse Indicates whether the work can be used commercially or not.
/// @param commercialAttribution whether attribution is required when reproducing the work commercially or not.
/// @param commercializerChecker commercializers that are allowed to commercially exploit the work. If zero address,
/// then no restrictions is enforced.
/// @param commercializerCheckerData The data to be passed to the commercializer checker contract.
/// @param commercialRevShare Percentage of revenue that must be shared with the licensor.
/// @param commercialRevCeiling The maximum revenue that can be generated from the commercial use of the work.
/// @param derivativesAllowed Indicates whether the licensee can create derivatives of his work or not.
/// @param derivativesAttribution Indicates whether attribution is required for derivatives of the work or not.
/// @param derivativesApproval Indicates whether the licensor must approve derivatives of the work before they can be
/// linked to the licensor IP ID or not.
/// @param derivativesReciprocal Indicates whether the licensee must license derivatives of the work under the
/// same terms or not.
/// @param derivativeRevCeiling The maximum revenue that can be generated from the derivative use of the work.
/// @param currency The ERC20 token to be used to pay the minting fee. the token must be registered in story protocol.
/// @param uri The URI of the license terms, which can be used to fetch the offchain license terms.
struct PILTerms {
    bool transferable;
    address royaltyPolicy;
    uint256 defaultMintingFee;
    uint256 expiration;
    bool commercialUse;
    bool commercialAttribution;
    address commercializerChecker;
    bytes commercializerCheckerData;
    uint32 commercialRevShare;
    uint256 commercialRevCeiling;
    bool derivativesAllowed;
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint256 derivativeRevCeiling;
    address currency;
    string uri;
}

/// @title IPILicenseTemplate
/// @notice This interface defines the methods for a Programmable IP License (PIL) template.
/// The PIL template is used to generate PIL terms that can be attached to IP Assets.
/// The legal document of the PIL can be found in this repository.
interface IPILicenseTemplate is ILicenseTemplate {
    /// @notice Registers new license terms.
    /// @param terms The PILTerms to register.
    /// @return selectedLicenseTermsId The ID of the newly registered license terms.
    function registerLicenseTerms(PILTerms calldata terms) external returns (uint256 selectedLicenseTermsId);

    /// @notice Gets the ID of the given license terms.
    /// @param terms The PILTerms to get the ID for.
    /// @return selectedLicenseTermsId The ID of the given license terms.
    function getLicenseTermsId(PILTerms calldata terms) external view returns (uint256 selectedLicenseTermsId);

    /// @notice Gets license terms of the given ID.
    /// @param selectedLicenseTermsId The ID of the license terms.
    /// @return terms The PILTerms associate with the given ID.
    function getLicenseTerms(uint256 selectedLicenseTermsId) external view returns (PILTerms memory terms);
}
