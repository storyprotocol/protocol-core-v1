// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ILicenseTemplate } from "../../../interfaces/modules/licensing/ILicenseTemplate.sol";


interface IPILicenseTemplate is ILicenseTemplate {
    struct LicenseTemplateTerms {
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

    event PILicenseRegistered(uint256 indexed licenseId, address indexed licenseTemplate, License license);

    function registerLicenseConfig(License calldata license) external returns (uint256 licenseId);
}
