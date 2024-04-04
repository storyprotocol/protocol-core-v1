// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ILicenseTemplate } from "../../../interfaces/modules/licensing/ILicenseTemplate.sol";

struct PILTerms {
    bool transferable;
    address royaltyPolicy;
    uint256 mintingFee;
    uint256 expiration;
    bool commercialUse;
    bool commercialAttribution;
    address commercializerChecker;
    bytes commercializerCheckerData;
    uint32 commercialRevShare;
    uint256 commercialRevCelling;
    bool derivativesAllowed;
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint256 derivativeRevCelling;
    address currency;
}

interface IPILicenseTemplate is ILicenseTemplate {
    function registerLicenseTerms(PILTerms calldata terms) external returns (uint256 selectedLicenseTermsId);
    function getLicenseTermsId(PILTerms calldata terms) external view returns (uint256 selectedLicenseTermsId);
}
