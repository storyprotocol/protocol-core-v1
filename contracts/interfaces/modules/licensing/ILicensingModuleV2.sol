// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IModule } from "../base/IModule.sol";

/// @title ILicensingModule
interface ILicensingModuleV2 is IModule {
    event LicenseTermsAttached(
        address indexed caller,
        address indexed ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    );

    event LicenseTokensMinted(
        address indexed caller,
        address indexed originalIpId,
        address licenseTemplate,
        uint256 indexed licenseTermsId,
        uint256 amount,
        address receiver,
        uint256 startLicenseTokenId,
        uint256 endLicenseTokenId
    );

    event DerivativeRegistered(
        address indexed caller,
        address indexed derivativeIpId,
        address[] originalIpIds,
        uint256[] licenseTermsIds,
        address licenseTemplate
    );

    event DerivativeRegisteredWithLicenseTokens(
        address indexed caller,
        address indexed derivativeIpId,
        uint256[] licenseTokenIds,
        address[] originalIpIds,
        uint256[] licenseTermsIds,
        address licenseTemplate
    );

    function attachLicenseTerms(address ipId, address licenseTemplate, uint256 licenseTermsId) external;

    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external returns (uint256 startLicenseTokenId, uint256 endLicenseTokenId);

    function registerDerivative(
        address derivativeIpId,
        address[] calldata originalIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        bytes calldata royaltyContext
    ) external;

    function registerDerivativeWithLicenseTokens(
        address derivativeIpId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external;
}
