// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Licensing } from "../../lib/Licensing.sol";

/// @title ILicenseRegistry
/// @notice This contract is responsible for maintaining relationships between IPs and their licenses,
/// parent and derivative IPs, registering License Templates, setting default licenses,
/// and managing royalty policies and currency tokens.
/// It serves as a central point for managing the licensing states within the Story Protocol ecosystem.
interface ILicenseRegistry {
    /// @notice Emitted when a new license template is registered.
    event LicenseTemplateRegistered(address indexed licenseTemplate);

    /// @notice Emitted when a minting license configuration is set.
    event LicensingConfigSetForLicense(
        address indexed ipId,
        address indexed licenseTemplate,
        uint256 indexed licenseTermsId
    );

    /// @notice Emitted when set new default license terms.
    event DefaultLicenseTermsSet(address licenseTemplate, uint256 licenseTermsId);

    /// @notice Emitted when a minting license configuration is set for all licenses of an IP.
    event LicensingConfigSetForIP(address indexed ipId, Licensing.LicensingConfig licensingConfig);

    /// @notice Emitted when an expiration time is set for an IP.
    event ExpirationTimeSet(address indexed ipId, uint256 expireTime);

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
    /// @param licenseTemplate The address of the license template to check.
    /// @return Whether the license template is registered.
    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool);

    /// @notice Registers a derivative IP and its relationship to parent IPs.
    /// @param ipId The address of the derivative IP.
    /// @param parentIpIds An array of addresses of the parent IPs.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsIds An array of IDs of the license terms.
    /// @param isUsingLicenseToken Whether the derivative IP is registered with license tokens.
    function registerDerivativeIp(
        address ipId,
        address[] calldata parentIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds,
        bool isUsingLicenseToken
    ) external;

    /// @notice Checks if an IP is a derivative IP.
    /// @param ipId The address of the IP to check.
    /// @return Whether the IP is a derivative IP.
    function isDerivativeIp(address ipId) external view returns (bool);

    /// @notice Checks if an IP has derivative IPs.
    /// @param ipId The address of the IP to check.
    /// @return Whether the IP has derivative IPs.
    function hasDerivativeIps(address ipId) external view returns (bool);

    /// @notice Verifies the minting of a license token.
    /// @param licensorIpId The address of the licensor IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms will mint the license token.
    /// @param isMintedByIpOwner Whether the license token is minted by the IP owner.
    /// @return The configuration for minting the license.
    function verifyMintLicenseToken(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bool isMintedByIpOwner
    ) external view returns (Licensing.LicensingConfig memory);

    /// @notice Attaches license terms to an IP.
    /// @param ipId The address of the IP to which the license terms are attached.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTermsToIp(address ipId, address licenseTemplate, uint256 licenseTermsId) external;

    /// @notice Checks if license terms exist.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the license terms exist.
    function exists(address licenseTemplate, uint256 licenseTermsId) external view returns (bool);

    /// @notice Checks if an IP has attached any license terms.
    /// @param ipId The address of the IP to check.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the IP has attached any license terms.
    function hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (bool);

    /// @notice Gets the attached license terms of an IP by its index.
    /// @param ipId The address of the IP.
    /// @param index The index of the attached license terms within the array of all attached license terms of the IP.
    /// @return licenseTemplate The address of the license template where the license terms are defined.
    /// @return licenseTermsId The ID of the license terms.
    function getAttachedLicenseTerms(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseTermsId);

    /// @notice Gets the count of attached license terms of an IP.
    /// @param ipId The address of the IP.
    /// @return The count of attached license terms.
    function getAttachedLicenseTermsCount(address ipId) external view returns (uint256);

    /// @notice got the derivative IP of an IP by its index.
    /// @param parentIpId The address of the IP.
    /// @param index The index of the derivative IP within the array of all derivative IPs of the IP.
    /// @return childIpId The address of the derivative IP.
    function getDerivativeIp(address parentIpId, uint256 index) external view returns (address childIpId);

    /// @notice Gets the count of derivative IPs of an IP.
    /// @param parentIpId The address of the IP.
    /// @return The count of derivative IPs.
    function getDerivativeIpCount(address parentIpId) external view returns (uint256);

    /// @notice got the parent IP of an IP by its index.
    /// @param childIpId The address of the IP.
    /// @param index The index of the parent IP within the array of all parent IPs of the IP.
    /// @return parentIpId The address of the parent IP.
    function getParentIp(address childIpId, uint256 index) external view returns (address parentIpId);

    /// @notice Checks if an IP is a parent IP.
    /// @param parentIpId The address of the parent IP.
    /// @param childIpId The address of the child IP.
    /// @return Whether the IP is a parent IP.
    function isParentIp(address parentIpId, address childIpId) external view returns (bool);

    /// @notice Gets the count of parent IPs.
    /// @param childIpId The address of the childIP.
    /// @return The count o parent IPs.
    function getParentIpCount(address childIpId) external view returns (uint256);

    /// @notice Retrieves the minting license configuration for a given license terms of the IP.
    /// Will return the configuration for the license terms of the IP if configuration is not set for the license terms.
    /// @param ipId The address of the IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The configuration for minting the license.
    function getLicensingConfig(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (Licensing.LicensingConfig memory);

    /// @notice Sets the minting license configuration for a specific license attached to a specific IP.
    /// @dev This function can only be called by the LicensingModule.
    /// @param ipId The address of the IP for which the configuration is being set.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param licensingConfig The configuration for minting the license.
    function setLicensingConfigForLicense(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        Licensing.LicensingConfig calldata licensingConfig
    ) external;

    /// @notice Sets the MintingLicenseConfig for an IP and applies it to all licenses attached to the IP.
    /// @dev This function will set a global configuration for all licenses under a specific IP.
    /// However, this global configuration can be overridden by a configuration set at a specific license level.
    /// @param ipId The IP ID for which the configuration is being set.
    /// @param licensingConfig The MintingLicenseConfig to be set for all licenses under the given IP.
    function setLicensingConfigForIp(address ipId, Licensing.LicensingConfig calldata licensingConfig) external;

    /// @notice Gets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @return The expiration time, 0 means never expired.
    function getExpireTime(address ipId) external view returns (uint256);

    /// @notice Checks if an IP is expired.
    /// @param ipId The address of the IP.
    /// @return Whether the IP is expired.
    function isExpiredNow(address ipId) external view returns (bool);

    /// @notice Returns the license terms through which a child IP links to a parent IP.
    /// @param childIpId The address of the child IP.
    /// @param parentIpId The address of the parent IP.
    /// @return licenseTemplate The address of the license template.
    /// @return licenseTermsId The ID of the license terms.
    function getParentLicenseTerms(
        address childIpId,
        address parentIpId
    ) external view returns (address licenseTemplate, uint256 licenseTermsId);
}
