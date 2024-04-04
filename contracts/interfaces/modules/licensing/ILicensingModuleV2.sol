// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IModule } from "../base/IModule.sol";

/// @title ILicensingModule
interface ILicensingModuleV2 is IModule {
    event LicenseConfigAttached(
        address indexed caller,
        address indexed ipId,
        address licenseTemplate,
        uint256 licenseId
    );

    event LicenseTokensMinted(
        address indexed caller,
        address indexed originalIpId,
        address licenseTemplate,
        uint256 indexed licenseId,
        uint256 amount,
        address receiver,
        uint256 startLicenseTokenId,
        uint256 endLicenseTokenId
    );

    event DerivativeRegistered(
        address indexed caller,
        address indexed derivativeIpId,
        address[] originalIpIds,
        uint256[] licenseConfigIds,
        address licenseTemplate
    );

    event DerivativeRegisteredWithLicenseTokens(
        address indexed caller,
        address indexed derivativeIpId,
        uint256[] licenseTokenIds,
        address[] originalIpIds,
        uint256[] licenseConfigIds,
        address licenseTemplate
    );

    function attachLicenseConfig(address ipId, address licenseTemplate, uint256 licenseId) external;

    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external returns (uint256 startLicenseTokenId, uint256 endLicenseTokenId);

    function registerDerivative(
        address derivativeIpId,
        address[] calldata originalIpIds,
        uint256[] calldata licenseIds,
        address licenseTemplate,
        bytes calldata royaltyContext
    ) external;

    function registerDerivativeWithLicenseTokens(
        address derivativeIpId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external;
}
