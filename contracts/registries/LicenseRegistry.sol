// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { ILicenseRegistry } from "../interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { IDisputeModule } from "../interfaces/modules/dispute/IDisputeModule.sol";
import { Errors } from "../lib/Errors.sol";
import { Licensing } from "../lib/Licensing.sol";
import { ExpiringOps } from "../lib/ExpiringOps.sol";
import { ILicenseTemplate } from "../interfaces/modules/licensing/ILicenseTemplate.sol";
import { IPAccountStorageOps } from "../lib/IPAccountStorageOps.sol";
import { IIPAccount } from "../interfaces/IIPAccount.sol";

/// @title LicenseRegistry aka LNFT
/// @notice Registry of License NFTs, which represent licenses granted by IP ID licensors to create derivative IPs.
/// @custom:oz-upgrades-from contracts/old/v1.0.0.sol:LicenseRegistry_V1_0_0
contract LicenseRegistry is ILicenseRegistry, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using IPAccountStorageOps for IIPAccount;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicensingModule public immutable LICENSING_MODULE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @dev Storage of the LicenseRegistry
    /// @param defaultLicenseTemplate The default license template address
    /// @param defaultLicenseTermsId The default license terms ID
    /// @param registeredLicenseTemplates Registered license templates
    /// @param registeredRoyaltyPolicies Registered royalty policies
    /// @param registeredCurrencyTokens Registered currency tokens
    /// @param parentIps Mapping of parent IPs to derivative IPs
    /// @param childIps Mapping of derivative IPs to parent IPs
    /// @param attachedLicenseTerms Mapping of attached license terms to IP IDs
    /// @param licenseTemplates Mapping of license templates to IP IDs
    /// @param expireTimes Mapping of IP IDs to expire times
    /// @param licensingConfigs Mapping of minting license configs to a licenseTerms of an IP
    /// @param licensingConfigsForIp Mapping of minting license configs to an IP,
    /// the config will apply to all licenses under the IP
    /// @dev Storage structure for the LicenseRegistry
    /// @custom:storage-location erc7201:story-protocol.LicenseRegistry
    struct LicenseRegistryStorage {
        /// @custom:oz-renamed-from licensingModule
        ILicensingModule deprecated_licensingModule;
        /// @custom:oz-renamed-from disputeModule
        IDisputeModule deprecated_disputeModule;
        address defaultLicenseTemplate;
        uint256 defaultLicenseTermsId;
        mapping(address licenseTemplate => bool isRegistered) registeredLicenseTemplates;
        mapping(address childIpId => EnumerableSet.AddressSet parentIpIds) parentIps;
        mapping(address parentIpId => EnumerableSet.AddressSet childIpIds) childIps;
        mapping(address ipId => EnumerableSet.UintSet licenseTermsIds) attachedLicenseTerms;
        mapping(address ipId => address licenseTemplate) licenseTemplates;
        mapping(bytes32 ipLicenseHash => Licensing.LicensingConfig licensingConfig) licensingConfigs;
        mapping(address ipId => Licensing.LicensingConfig licensingConfig) licensingConfigsForIp;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicenseRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseRegistryStorageLocation =
        0x5ed898e10dedf257f39672a55146f3fecade9da16f4ff022557924a10d60a900;

    bytes32 public constant EXPIRATION_TIME = "EXPIRATION_TIME";

    modifier onlyLicensingModule() {
        if (msg.sender != address(LICENSING_MODULE)) {
            revert Errors.LicenseRegistry__CallerNotLicensingModule();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address licensingModule, address disputeModule) {
        if (licensingModule == address(0)) revert Errors.LicenseRegistry__ZeroLicensingModule();
        if (disputeModule == address(0)) revert Errors.LicenseRegistry__ZeroDisputeModule();
        LICENSING_MODULE = ILicensingModule(licensingModule);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.LicenseRegistry__ZeroAccessManager();
        }
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Sets the default license terms that are attached to all IPs by default.
    /// @param newLicenseTemplate The address of the new default license template.
    /// @param newLicenseTermsId The ID of the new default license terms.
    function setDefaultLicenseTerms(address newLicenseTemplate, uint256 newLicenseTermsId) external restricted {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.defaultLicenseTemplate = newLicenseTemplate;
        $.defaultLicenseTermsId = newLicenseTermsId;
    }

    /// @notice Registers a new license template in the Story Protocol.
    /// @param licenseTemplate The address of the license template to register.
    function registerLicenseTemplate(address licenseTemplate) external restricted {
        if (!licenseTemplate.supportsInterface(type(ILicenseTemplate).interfaceId)) {
            revert Errors.LicenseRegistry__NotLicenseTemplate(licenseTemplate);
        }
        _getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate] = true;
        emit LicenseTemplateRegistered(licenseTemplate);
    }

    /// @notice Sets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @param expireTime The new expiration time, 0 means never expired.
    function setExpireTime(address ipId, uint256 expireTime) external onlyLicensingModule {
        _setExpirationTime(ipId, expireTime);
    }

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
    ) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        $.licensingConfigs[_getIpLicenseHash(ipId, licenseTemplate, licenseTermsId)] = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: licensingConfig.mintingFee,
            licensingHook: licensingConfig.licensingHook,
            hookData: licensingConfig.hookData
        });

        emit LicensingConfigSetForLicense(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Sets the LicensingConfig for an IP and applies it to all licenses attached to the IP.
    /// @dev This function will set a global configuration for all licenses under a specific IP.
    /// However, this global configuration can be overridden by a configuration set at a specific license level.
    /// @param ipId The IP ID for which the configuration is being set.
    /// @param licensingConfig The LicensingConfig to be set for all licenses under the given IP.
    function setLicensingConfigForIp(
        address ipId,
        Licensing.LicensingConfig calldata licensingConfig
    ) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.licensingConfigsForIp[ipId] = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: licensingConfig.mintingFee,
            licensingHook: licensingConfig.licensingHook,
            hookData: licensingConfig.hookData
        });
        emit LicensingConfigSetForIP(ipId, licensingConfig);
    }

    /// @notice Attaches license terms to an IP.
    /// @param ipId The address of the IP to which the license terms are attached.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTermsToIp(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external onlyLicensingModule {
        if (!_exists(licenseTemplate, licenseTermsId)) {
            revert Errors.LicensingModule__LicenseTermsNotFound(licenseTemplate, licenseTermsId);
        }

        if (_isExpiredNow(ipId)) {
            revert Errors.LicenseRegistry__IpExpired(ipId);
        }

        if (_hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__LicenseTermsAlreadyAttached(ipId, licenseTemplate, licenseTermsId);
        }

        if (_isDerivativeIp(ipId)) {
            revert Errors.LicensingModule__DerivativesCannotAddLicenseTerms();
        }

        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.licenseTemplates[ipId] != address(0) && $.licenseTemplates[ipId] != licenseTemplate) {
            revert Errors.LicenseRegistry__UnmatchedLicenseTemplate(ipId, $.licenseTemplates[ipId], licenseTemplate);
        }

        $.licenseTemplates[ipId] = licenseTemplate;
        $.attachedLicenseTerms[ipId].add(licenseTermsId);
    }

    /// @notice Registers a derivative IP and its relationship to parent IPs.
    /// @param childIpId The address of the derivative IP.
    /// @param parentIpIds An array of addresses of the parent IPs.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsIds An array of IDs of the license terms.
    function registerDerivativeIp(
        address childIpId,
        address[] calldata parentIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) external onlyLicensingModule {
        if (parentIpIds.length == 0) {
            revert Errors.LicenseRegistry__NoParentIp();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.parentIps[childIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeAlreadyRegistered(childIpId);
        }
        if ($.attachedLicenseTerms[childIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense(childIpId);
        }
        // earliest expiration time
        uint256 earliestExp = 0;
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            earliestExp = ExpiringOps.getEarliestExpirationTime(earliestExp, _getExpireTime(parentIpIds[i]));
            _verifyDerivativeFromParent(parentIpIds[i], childIpId, licenseTemplate, licenseTermsIds[i]);
            $.childIps[parentIpIds[i]].add(childIpId);
            // determine if duplicate license terms
            bool isNewParent = $.parentIps[childIpId].add(parentIpIds[i]);
            bool isNewTerms = $.attachedLicenseTerms[childIpId].add(licenseTermsIds[i]);
            if (!isNewParent && !isNewTerms) {
                revert Errors.LicenseRegistry__DuplicateLicense(parentIpIds[i], licenseTemplate, licenseTermsIds[i]);
            }
        }
        $.licenseTemplates[childIpId] = licenseTemplate;
        // calculate the earliest expiration time of child IP with both parent IPs and license terms
        earliestExp = _calculateEarliestExpireTime(earliestExp, licenseTemplate, licenseTermsIds);
        // default value is 0 which means that the license never expires
        if (earliestExp != 0) _setExpirationTime(childIpId, earliestExp);
    }

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
    ) external view returns (Licensing.LicensingConfig memory) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (_isExpiredNow(licensorIpId)) {
            revert Errors.LicenseRegistry__ParentIpExpired(licensorIpId);
        }
        if (isMintedByIpOwner) {
            if (!_exists(licenseTemplate, licenseTermsId)) {
                revert Errors.LicenseRegistry__LicenseTermsNotExists(licenseTemplate, licenseTermsId);
            }
        } else if (!_hasIpAttachedLicenseTerms(licensorIpId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__LicensorIpHasNoLicenseTerms(licensorIpId, licenseTemplate, licenseTermsId);
        }
        return _getLicensingConfig(licensorIpId, licenseTemplate, licenseTermsId);
    }

    /// @notice Checks if a license template is registered.
    /// @param licenseTemplate The address of the license template to check.
    /// @return Whether the license template is registered.
    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool) {
        return _getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate];
    }

    /// @notice Checks if an IP is a derivative IP.
    /// @param childIpId The address of the IP to check.
    /// @return Whether the IP is a derivative IP.
    function isDerivativeIp(address childIpId) external view returns (bool) {
        return _isDerivativeIp(childIpId);
    }

    /// @notice Checks if an IP has derivative IPs.
    /// @param parentIpId The address of the IP to check.
    /// @return Whether the IP has derivative IPs.
    function hasDerivativeIps(address parentIpId) external view returns (bool) {
        return _getLicenseRegistryStorage().childIps[parentIpId].length() > 0;
    }

    /// @notice Checks if license terms exist.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the license terms exist.
    function exists(address licenseTemplate, uint256 licenseTermsId) external view returns (bool) {
        return _exists(licenseTemplate, licenseTermsId);
    }

    /// @notice Checks if an IP has attached any license terms.
    /// @param ipId The address of the IP to check.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the IP has attached any license terms.
    function hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (bool) {
        return _hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Gets the attached license terms of an IP by its index.
    /// @param ipId The address of the IP.
    /// @param index The index of the attached license terms within the array of all attached license terms of the IP.
    /// @return licenseTemplate The address of the license template where the license terms are defined.
    /// @return licenseTermsId The ID of the license terms.
    function getAttachedLicenseTerms(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.attachedLicenseTerms[ipId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(ipId, index, $.attachedLicenseTerms[ipId].length());
        }
        licenseTemplate = $.licenseTemplates[ipId];
        licenseTermsId = $.attachedLicenseTerms[ipId].at(index);
    }

    /// @notice Gets the count of attached license terms of an IP.
    /// @param ipId The address of the IP.
    /// @return The count of attached license terms.
    function getAttachedLicenseTermsCount(address ipId) external view returns (uint256) {
        return _getLicenseRegistryStorage().attachedLicenseTerms[ipId].length();
    }

    /// @notice Gets the derivative IP of an IP by its index.
    /// @param parentIpId The address of the IP.
    /// @param index The index of the derivative IP within the array of all derivative IPs of the IP.
    /// @return childIpId The address of the derivative IP.
    function getDerivativeIp(address parentIpId, uint256 index) external view returns (address childIpId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.childIps[parentIpId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(parentIpId, index, $.childIps[parentIpId].length());
        }
        childIpId = $.childIps[parentIpId].at(index);
    }

    /// @notice Gets the count of derivative IPs of an IP.
    /// @param parentIpId The address of the IP.
    /// @return The count of derivative IPs.
    function getDerivativeIpCount(address parentIpId) external view returns (uint256) {
        return _getLicenseRegistryStorage().childIps[parentIpId].length();
    }

    /// @notice got the parent IP of an IP by its index.
    /// @param childIpId The address of the IP.
    /// @param index The index of the parent IP within the array of all parent IPs of the IP.
    /// @return parentIpId The address of the parent IP.
    function getParentIp(address childIpId, uint256 index) external view returns (address parentIpId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.parentIps[childIpId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(childIpId, index, $.parentIps[childIpId].length());
        }
        parentIpId = $.parentIps[childIpId].at(index);
    }

    function isParentIp(address parentIpId, address childIpId) external view returns (bool) {
        return _getLicenseRegistryStorage().parentIps[childIpId].contains(parentIpId);
    }

    /// @notice Gets the count of parent IPs.
    /// @param childIpId The address of the childIP.
    /// @return The count o parent IPs.
    function getParentIpCount(address childIpId) external view returns (uint256) {
        return _getLicenseRegistryStorage().parentIps[childIpId].length();
    }

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
    ) external view returns (Licensing.LicensingConfig memory) {
        return _getLicensingConfig(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Gets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @return The expiration time, 0 means never expired.
    function getExpireTime(address ipId) external view returns (uint256) {
        return _getExpireTime(ipId);
    }

    /// @notice Checks if an IP is expired.
    /// @param ipId The address of the IP.
    /// @return Whether the IP is expired.
    function isExpiredNow(address ipId) external view returns (bool) {
        return _isExpiredNow(ipId);
    }

    /// @notice Returns the default license terms.
    function getDefaultLicenseTerms() external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        return ($.defaultLicenseTemplate, $.defaultLicenseTermsId);
    }

    /// @dev verify the child IP can be registered as a derivative of the parent IP
    /// @param parentIpId The address of the parent IP
    /// @param childIpId The address of the child IP
    /// @param licenseTemplate The address of the license template where the license terms are created
    /// @param licenseTermsId The license terms the child IP is registered with
    function _verifyDerivativeFromParent(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (DISPUTE_MODULE.isIpTagged(parentIpId)) {
            revert Errors.LicenseRegistry__ParentIpTagged(parentIpId);
        }
        if (childIpId == parentIpId) {
            revert Errors.LicenseRegistry__DerivativeIsParent(childIpId);
        }
        if (_isExpiredNow(parentIpId)) {
            revert Errors.LicenseRegistry__ParentIpExpired(parentIpId);
        }
        // childIp can only register with default license terms or the license terms attached to the parent IP
        if ($.defaultLicenseTemplate != licenseTemplate || $.defaultLicenseTermsId != licenseTermsId) {
            if ($.licenseTemplates[parentIpId] != licenseTemplate) {
                revert Errors.LicenseRegistry__ParentIpUnmatchedLicenseTemplate(parentIpId, licenseTemplate);
            }
            if (!$.attachedLicenseTerms[parentIpId].contains(licenseTermsId)) {
                revert Errors.LicenseRegistry__ParentIpHasNoLicenseTerms(parentIpId, licenseTermsId);
            }
        }
    }

    /// @dev Calculate the earliest expiration time of the child IP with both parent IPs and license terms
    /// @param earliestParentIpExp The earliest expiration time of among all parent IPs
    /// @param licenseTemplate The address of the license template where the license terms are created
    /// @param licenseTermsIds The license terms the child IP is registered with
    function _calculateEarliestExpireTime(
        uint256 earliestParentIpExp,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) internal view returns (uint256 earliestExp) {
        uint256 licenseExp = ILicenseTemplate(licenseTemplate).getEarlierExpireTime(licenseTermsIds, block.timestamp);
        earliestExp = ExpiringOps.getEarliestExpirationTime(earliestParentIpExp, licenseExp);
    }

    /// @dev Get the expiration time of an IP
    /// @param ipId The address of the IP
    function _getExpireTime(address ipId) internal view returns (uint256) {
        return IIPAccount(payable(ipId)).getUint256(EXPIRATION_TIME);
    }

    /// @dev Check if an IP is expired now
    /// @param ipId The address of the IP
    function _isExpiredNow(address ipId) internal view returns (bool) {
        uint256 expireTime = _getExpireTime(ipId);
        return expireTime != 0 && expireTime < block.timestamp;
    }

    /// @dev Set the expiration time of an IP
    /// @param ipId The address of the IP
    /// @param expireTime The expiration time
    function _setExpirationTime(address ipId, uint256 expireTime) internal {
        IIPAccount(payable(ipId)).setUint256(EXPIRATION_TIME, expireTime);
        emit ExpirationTimeSet(ipId, expireTime);
    }

    /// @dev Check if an IP is a derivative/child IP
    /// @param childIpId The address of the IP
    function _isDerivativeIp(address childIpId) internal view returns (bool) {
        return _getLicenseRegistryStorage().parentIps[childIpId].length() > 0;
    }

    /// @dev Retrieves the minting license configuration for a given license terms of the IP.
    /// Will return the configuration for the license terms of the IP if configuration is not set for the license terms.
    /// @param ipId The address of the IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    function _getLicensingConfig(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (Licensing.LicensingConfig memory) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        if ($.licensingConfigs[_getIpLicenseHash(ipId, licenseTemplate, licenseTermsId)].isSet) {
            return $.licensingConfigs[_getIpLicenseHash(ipId, licenseTemplate, licenseTermsId)];
        }
        return $.licensingConfigsForIp[ipId];
    }

    /// @dev Get the hash of the IP ID, license template, and license terms ID
    /// @param ipId The address of the IP
    /// @param licenseTemplate The address of the license template
    /// @param licenseTermsId The ID of the license terms
    function _getIpLicenseHash(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(ipId, licenseTemplate, licenseTermsId));
    }

    /// @dev Check if an IP has attached given license terms
    /// @param ipId The address of the IP
    /// @param licenseTemplate The address of the license template
    /// @param licenseTermsId The ID of the license terms
    function _hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (bool) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.defaultLicenseTemplate == licenseTemplate && $.defaultLicenseTermsId == licenseTermsId) return true;
        return $.licenseTemplates[ipId] == licenseTemplate && $.attachedLicenseTerms[ipId].contains(licenseTermsId);
    }

    /// @dev Check if license terms has been defined in the license template
    /// @param licenseTemplate The address of the license template
    /// @param licenseTermsId The ID of the license terms
    function _exists(address licenseTemplate, uint256 licenseTermsId) internal view returns (bool) {
        if (!_getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate]) {
            return false;
        }
        return ILicenseTemplate(licenseTemplate).exists(licenseTermsId);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    function _getLicenseRegistryStorage() internal pure returns (LicenseRegistryStorage storage $) {
        assembly {
            $.slot := LicenseRegistryStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
