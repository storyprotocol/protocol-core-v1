// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Licensing } from "../../lib/Licensing.sol";

/// @title ILicenseRegistry
/// @notice This contract is responsible for maintaining relationships between IPs and their licenses,
/// original and derivative IPs, registering License Templates, setting default licenses,
/// and managing royalty policies and currency tokens.
/// It serves as a central point for managing the licensing states within the Story Protocol ecosystem.
interface ILicenseRegistryV2 {
    /// @notice Emitted when a new license template is registered.
    event LicenseTemplateRegistered(address indexed licenseTemplate);

    /// @notice Emitted when a new royalty policy is registered.
    event RoyaltyPolicyRegistered(address indexed royaltyPolicy);

    /// @notice Emitted when a new currency token is registered.
    event CurrencyTokenRegistered(address indexed token);

    /// @notice Emitted when a minting license specification is set.
    event MintingLicenseSpecSet(
        address indexed ipId,
        address indexed licenseTemplate,
        uint256 indexed licenseTermsId,
        Licensing.MintingLicenseSpec mintingLicenseSpec
    );

    /// @notice Emitted when a minting license specification is set for all licenses of an IP.
    event MintingLicenseSpecSetForAll(address indexed ipId, Licensing.MintingLicenseSpec mintingLicenseSpec);

    /// @notice Emitted when an expiration time is set for an IP.
    event ExpireTimeSet(address indexed ipId, uint256 expireTime);

    /// @notice Sets the default license terms that are attached to all IPs by default.
    /// @param newLicenseTemplate The address of the new default license template.
    /// @param newLicenseTermsId The ID of the new default license terms.
    function setDefaultLicenseTerms(address newLicenseTemplate, uint256 newLicenseTermsId) external;

    /// @notice Returns the default license terms.
    function getDefaultLicenseTerms() external view returns (address licenseTemplate, uint256 licenseTermsId);

    /// @notice Registers a new license template in the Story Protocol.
    /// @param licenseTemplate The address of the license template to register.
    function registerLicenseTemplate(address licenseTemplate) external;

    /// @notice Checks if a license template is registered.
    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool);

    /// @notice Registers a new royalty policy in the Story Protocol.
    /// @param royaltyPolicy The address of the royalty policy to register.
    function registerRoyaltyPolicy(address royaltyPolicy) external;

    /// @notice Checks if a royalty policy is registered.
    function isRegisteredRoyaltyPolicy(address royaltyPolicy) external view returns (bool);

    /// @notice Registers a new currency token used for paying license token minting fees and royalties.
    /// @param token The address of the currency token to register.
    function registerCurrencyToken(address token) external;

    /// @notice Checks if a currency token is registered.
    function isRegisteredCurrencyToken(address token) external view returns (bool);

    /// @notice Registers a derivative IP and its relationship to original IPs.
    /// @param ipId The address of the derivative IP.
    /// @param originalIpIds An array of addresses of the original IPs.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsIds An array of IDs of the license terms.
    function registerDerivativeIp(
        address ipId,
        address[] calldata originalIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) external;

    /// @notice Checks if an IP is a derivative IP.
    function isDerivativeIp(address ipId) external view returns (bool);

    /// @notice Checks if an IP has derivative IPs.
    function hasDerivativeIps(address ipId) external view returns (bool);

    /// @notice Verifies the minting of a license token.
    function verifyMintLicenseToken(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bool isMintedByIpOwner
    ) external view returns (Licensing.MintingLicenseSpec memory);

    /// @notice Attaches license terms to an IP.
    /// @param ipId The address of the IP to which the license terms are attached.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsIds The ID of the license terms.
    function attachLicenseTermsToIp(address ipId, address licenseTemplate, uint256 licenseTermsIds) external;

    /// @notice Checks if license terms exist.
    function existsLicenseTerms(address licenseTemplate, uint256 licenseTermsId) external view returns (bool);

    /// @notice Checks if an IP has attached license terms.
    function hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (bool);

    /// @notice Gets the attached license terms of an IP.
    function getAttachedLicenseTerms(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseTermsId);

    /// @notice Gets the count of attached license terms of an IP.
    function getAttachedLicenseTermsCount(address ipId) external view returns (uint256);

    /// @notice Retrieves the minting license specification for a given IP, license template, and license terms ID.
    function getMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (Licensing.MintingLicenseSpec memory);

    /// @notice Sets the minting license specification for a given IP, license template, and license terms ID.
    function setMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        Licensing.MintingLicenseSpec calldata mintingLicenseSpec
    ) external;

    /// @notice Sets the minting license specification for all licenser terms of given IP.
    function setMintingLicenseSpecForAll(
        address ipId,
        Licensing.MintingLicenseSpec calldata mintingLicenseSpec
    ) external;

    /// @notice Sets the expiration time for an IP.
    function setExpireTime(address ipId, uint256 expireTime) external;

    /// @notice Gets the expiration time for an IP.
    function getExpireTime(address ipId) external view returns (uint256);
}
