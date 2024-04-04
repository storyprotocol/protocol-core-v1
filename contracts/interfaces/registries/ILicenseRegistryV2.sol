// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Licensing } from "../../lib/Licensing.sol";

/// @title ILicenseRegistry
interface ILicenseRegistryV2 {
    struct LicenseStatus {
        bool attached;
        bool active;
        address licenseTemplate;
        uint256 expireTime;
    }

    event LicenseTemplateRegistered(address indexed licenseTemplate);
    event RoyaltyPolicyRegistered(address indexed royaltyPolicy);
    event CurrencyTokenRegistered(address indexed token);
    event MintingLicenseSpecSet(
        address indexed ipId,
        address indexed licenseTemplate,
        uint256 indexed licenseConfigId,
        Licensing.MintingLicenseSpec mintingLicenseSpec
    );
    event MintingLicenseSpecSetForAll(address indexed ipId, Licensing.MintingLicenseSpec mintingLicenseSpec);
    event ExpireTimeSet(address indexed ipId, uint256 expireTime);

    function setDefaultLicenseConfig(address newLicenseTemplate, uint256 newLicenseConfigId) external;
    function getDefaultLicenseConfig() external view returns (address licenseTemplate, uint256 licenseConfigId);

    function registerLicenseTemplate(address licenseTemplate) external;
    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool);

    function registerRoyaltyPolicy(address royaltyPolicy) external;
    function isRegisteredRoyaltyPolicy(address royaltyPolicy) external view returns (bool);

    function registerCurrencyToken(address token) external;
    function isRegisteredCurrencyToken(address token) external view returns (bool);

    function registerDerivativeIp(
        address ipId,
        address[] calldata originalIpIds,
        address licenseTemplate,
        uint256[] calldata licenseConfigIds
    ) external;
    function isDerivativeIp(address ipId) external view returns (bool);
    function hasDerivativeIps(address ipId) external view returns (bool);

    function verifyMintLicenseToken(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseConfigId,
        bool isMintedByIpOwner
    ) external view returns (Licensing.MintingLicenseSpec memory);

    function attachLicenseConfigToIp(address ipId, address licenseTemplate, uint256 licenseConfigIds) external;
    function existsLicenseConfig(address licenseTemplate, uint256 licenseConfigId) external view returns (bool);
    function hasIpAttachedLicenseConfig(
        address ipId,
        address licenseTemplate,
        uint256 licenseConfigId
    ) external view returns (bool);
    function getAttachedLicenseConfig(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseConfigId);
    function getAttachedLicenseConfigCount(address ipId) external view returns (uint256);

    function getMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseConfigId
    ) external view returns (Licensing.MintingLicenseSpec memory);

    function setMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseConfigId,
        Licensing.MintingLicenseSpec calldata mintingLicenseSpec
    ) external;

    function setMintingLicenseSpecForAll(
        address ipId,
        Licensing.MintingLicenseSpec calldata mintingLicenseSpec
    ) external;

    function setExpireTime(address ipId, uint256 expireTime) external;
    function getExpireTime(address ipId) external view returns (uint256);
}
