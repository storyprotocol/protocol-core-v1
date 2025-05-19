// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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
import { IPGraphACL } from "../access/IPGraphACL.sol";
import { IGroupIPAssetRegistry } from "../interfaces/registries/IGroupIPAssetRegistry.sol";
import { IIPAssetRegistry } from "../interfaces/registries/IIPAssetRegistry.sol";

/// @title LicenseRegistry aka LNFT
/// @notice Registry of License NFTs, which represent licenses granted by IP ID licensors to create derivative IPs.
contract LicenseRegistry is ILicenseRegistry, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using IPAccountStorageOps for IIPAccount;

    /// @notice A derivative IP can have 16 parent IPs at most.
    uint256 public constant MAX_PARENTS = 16;

    /// @notice A derivative IP can have 1024 ancestor IPs at most.
    uint256 public constant MAX_ANCESTORS = 1024;
    address public constant IP_GRAPH = address(0x0101);
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable GROUP_IP_ASSET_REGISTRY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicensingModule public immutable LICENSING_MODULE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IPGraphACL public immutable IP_GRAPH_ACL;

    /// @dev Storage of the LicenseRegistry
    /// @param defaultLicenseTemplate The default license template address
    /// @param defaultLicenseTermsId The default license terms ID
    /// @param registeredLicenseTemplates Registered license templates
    /// @param registeredRoyaltyPolicies Registered royalty policies
    /// @param registeredCurrencyTokens Registered currency tokens
    /// @param parentIps Mapping of parent IPs to derivative IPs
    /// @param parentLicenseTerms Mapping of parent IPs to license terms used to link to derivative IPs
    /// @param childIps Mapping of derivative IPs to parent IPs
    /// @param attachedLicenseTerms Mapping of attached license terms to IP IDs
    /// @param licenseTemplates Mapping of license templates to IP IDs
    /// @param expireTimes Mapping of IP IDs to expire times
    /// @param licensingConfigs Mapping of minting license configs to a licenseTerms of an IP
    /// @dev Storage structure for the LicenseRegistry
    /// @custom:storage-location erc7201:story-protocol.LicenseRegistry
    struct LicenseRegistryStorage {
        address defaultLicenseTemplate;
        uint256 defaultLicenseTermsId;
        mapping(address licenseTemplate => bool isRegistered) registeredLicenseTemplates;
        mapping(address childIpId => EnumerableSet.AddressSet parentIpIds) parentIps;
        mapping(address childIpId => mapping(address parentIpId => uint256 licenseTermsId)) parentLicenseTerms;
        mapping(address parentIpId => EnumerableSet.AddressSet childIpIds) childIps;
        mapping(address ipId => EnumerableSet.UintSet licenseTermsIds) attachedLicenseTerms;
        mapping(address ipId => address licenseTemplate) licenseTemplates;
        mapping(bytes32 ipLicenseHash => Licensing.LicensingConfig licensingConfig) licensingConfigs;
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
    constructor(address groupIpAssetRegistry, address licensingModule, address disputeModule, address ipGraphAcl) {
        if (groupIpAssetRegistry == address(0)) revert Errors.LicenseRegistry__ZeroGroupIpRegistry();
        if (licensingModule == address(0)) revert Errors.LicenseRegistry__ZeroLicensingModule();
        if (disputeModule == address(0)) revert Errors.LicenseRegistry__ZeroDisputeModule();
        if (ipGraphAcl == address(0)) revert Errors.LicenseRegistry__ZeroIPGraphACL();
        GROUP_IP_ASSET_REGISTRY = IGroupIPAssetRegistry(groupIpAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        IP_GRAPH_ACL = IPGraphACL(ipGraphAcl);
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
        if (newLicenseTemplate == address(0)) {
            revert Errors.LicenseRegistry__ZeroLicenseTemplate();
        }
        if (!_exists(newLicenseTemplate, newLicenseTermsId)) {
            revert Errors.LicenseRegistry__LicenseTermsNotExists(newLicenseTemplate, newLicenseTermsId);
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.defaultLicenseTemplate = newLicenseTemplate;
        $.defaultLicenseTermsId = newLicenseTermsId;
        emit DefaultLicenseTermsSet(newLicenseTemplate, newLicenseTermsId);
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
            isSet: licensingConfig.isSet,
            mintingFee: licensingConfig.mintingFee,
            licensingHook: licensingConfig.licensingHook,
            hookData: licensingConfig.hookData,
            commercialRevShare: licensingConfig.commercialRevShare,
            disabled: licensingConfig.disabled,
            expectMinimumGroupRewardShare: licensingConfig.expectMinimumGroupRewardShare,
            expectGroupRewardPool: licensingConfig.expectGroupRewardPool
        });

        emit LicensingConfigSetForLicense(ipId, licenseTemplate, licenseTermsId, licensingConfig);
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
        // The group can only attach one license terms which is common for all members.
        if (GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(ipId)) {
            if (_getLicenseRegistryStorage().attachedLicenseTerms[ipId].length() > 0) {
                revert Errors.LicenseRegistry__GroupIpAlreadyHasLicenseTerms(ipId);
            }
            if (!ILicenseTemplate(licenseTemplate).canAttachToGroupIp(licenseTermsId)) {
                revert Errors.LicenseRegistry__LicenseTermsCannotAttachToGroupIp(licenseTemplate, licenseTermsId);
            }
        }

        if (_isExpiredNow(ipId)) {
            revert Errors.LicenseRegistry__IpExpired(ipId);
        }

        if (_hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__LicenseTermsAlreadyAttached(ipId, licenseTemplate, licenseTermsId);
        }

        IP_GRAPH_ACL.startInternalAccess();
        if (_isDerivativeIp(ipId)) {
            revert Errors.LicensingModule__DerivativesCannotAddLicenseTerms();
        }
        IP_GRAPH_ACL.endInternalAccess();

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
    /// @param isUsingLicenseToken Whether the derivative IP is registered with license tokens.
    // solhint-disable code-complexity
    function registerDerivativeIp(
        address childIpId,
        address[] calldata parentIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds,
        bool isUsingLicenseToken
    ) external onlyLicensingModule {
        if (parentIpIds.length > MAX_PARENTS) {
            revert Errors.LicenseRegistry__TooManyParents(childIpId, parentIpIds.length, MAX_PARENTS);
        }

        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();

        IP_GRAPH_ACL.startInternalAccess();
        if (_isDerivativeIp(childIpId)) {
            revert Errors.LicenseRegistry__DerivativeAlreadyRegistered(childIpId);
        }
        IP_GRAPH_ACL.endInternalAccess();

        if ($.childIps[childIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeIpAlreadyHasChild(childIpId);
        }
        if ($.attachedLicenseTerms[childIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense(childIpId);
        }
        // earliest expiration time
        uint256 earliestExp = 0;
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            bool isRegisteredGroup = GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(parentIpIds[i]);
            if (isRegisteredGroup && parentIpIds.length > 1) {
                revert Errors.LicenseRegistry__GroupMustBeSoleParent(childIpId, parentIpIds[i]);
            }
            if (
                !isRegisteredGroup && !IIPAssetRegistry(address(GROUP_IP_ASSET_REGISTRY)).isRegistered(parentIpIds[i])
            ) {
                revert Errors.LicenseRegistry__ParentIpNotRegistered(parentIpIds[i]);
            }
            earliestExp = ExpiringOps.getEarliestExpirationTime(earliestExp, _getExpireTime(parentIpIds[i]));
            _verifyDerivativeFromParent(
                parentIpIds[i],
                childIpId,
                licenseTemplate,
                licenseTermsIds[i],
                isUsingLicenseToken
            );
            $.childIps[parentIpIds[i]].add(childIpId);
            // determine if duplicate parent IP
            bool isNewParent = $.parentIps[childIpId].add(parentIpIds[i]);
            if (!isNewParent) {
                revert Errors.LicenseRegistry__DuplicateParentIp(childIpId, parentIpIds[i]);
            }
            $.attachedLicenseTerms[childIpId].add(licenseTermsIds[i]);
            // link child IP to parent IP with license terms
            $.parentLicenseTerms[childIpId][parentIpIds[i]] = licenseTermsIds[i];
        }

        // Note: The IPGraph does not validate the parent-child relationship.
        // It only adds the parent IP to the child IP.
        // All the validation is done in the LicensingModule:
        // 1. Should be no duplicate parent IP.
        // 2. Should not addParentIp again to the same child IP.
        // 3. Should over max parents limitation.
        // 4. Should over max ancestors limitation.
        (bool success, ) = IP_GRAPH.call(
            abi.encodeWithSignature("addParentIp(address,address[])", childIpId, parentIpIds)
        );

        if (!success) {
            revert Errors.LicenseRegistry__AddParentIpToIPGraphFailed(childIpId, parentIpIds);
        }

        IP_GRAPH_ACL.startInternalAccess();
        uint256 ancestors = _getAncestorIpsCount(childIpId);
        IP_GRAPH_ACL.endInternalAccess();

        if (ancestors > MAX_ANCESTORS) {
            revert Errors.LicenseRegistry__TooManyAncestors(childIpId, ancestors, MAX_ANCESTORS);
        }

        $.licenseTemplates[childIpId] = licenseTemplate;
        // calculate the earliest expiration time of child IP with both parent IPs and license terms
        earliestExp = _calculateEarliestExpireTime(earliestExp, licenseTemplate, licenseTermsIds);
        // default value is 0 which means that the license never expires
        if (earliestExp != 0) _setExpirationTime(childIpId, earliestExp);
    }

    /// @notice set license template for an IP, if the IP has no license template set.
    /// @param ipId The address of the IP to which the license template is attached.
    /// @param licenseTemplate The address of the license template.
    /// @dev This function can only be called by the LicensingModule.
    function initializeLicenseTemplate(address ipId, address licenseTemplate) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (licenseTemplate == address(0)) revert Errors.LicenseRegistry__ZeroLicenseTemplate();
        // check if registered license template
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        if ($.licenseTemplates[ipId] == address(0)) $.licenseTemplates[ipId] = licenseTemplate;
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
        if (
            GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(licensorIpId) &&
            GROUP_IP_ASSET_REGISTRY.totalMembers(licensorIpId) == 0
        ) {
            revert Errors.LicenseRegistry__EmptyGroupCannotMintLicenseToken(licensorIpId);
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (_isExpiredNow(licensorIpId)) {
            revert Errors.LicenseRegistry__ParentIpExpired(licensorIpId);
        }
        if (isMintedByIpOwner && !GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(licensorIpId)) {
            if (!_exists(licenseTemplate, licenseTermsId)) {
                revert Errors.LicenseRegistry__LicenseTermsNotExists(licenseTemplate, licenseTermsId);
            }

            if ($.licenseTemplates[licensorIpId] != address(0) && licenseTemplate != $.licenseTemplates[licensorIpId]) {
                revert Errors.LicenseRegistry__UnmatchedLicenseTemplate(
                    licensorIpId,
                    $.licenseTemplates[licensorIpId],
                    licenseTemplate
                );
            }
        } else if (!_hasIpAttachedLicenseTerms(licensorIpId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__LicensorIpHasNoLicenseTerms(licensorIpId, licenseTemplate, licenseTermsId);
        }
        return _getLicensingConfig(licensorIpId, licenseTemplate, licenseTermsId);
    }

    /// @notice Verifies the group can add given IP.
    /// @param groupId The address of the group.
    /// @param groupRewardPool The address of the reward pool of the group.
    /// @param ipId The address of the IP to be added to the group.
    /// @param groupLicenseTemplate the address of the license template attached to the group.
    /// the IP must have this license template.
    /// @param groupLicenseTermsId The ID of the license terms attached to the group.
    /// the IP must have this license terms.
    /// @return ipLicensingConfig The configuration for license attached to the IP.
    // solhint-disable code-complexity
    function verifyGroupAddIp(
        address groupId,
        address groupRewardPool,
        address ipId,
        address groupLicenseTemplate,
        uint256 groupLicenseTermsId
    ) external view returns (Licensing.LicensingConfig memory ipLicensingConfig) {
        // check if the IP has the same license terms as the group
        if (!_hasIpAttachedLicenseTerms(ipId, groupLicenseTemplate, groupLicenseTermsId)) {
            revert Errors.LicenseRegistry__IpHasNoGroupLicenseTerms(ipId, groupLicenseTemplate, groupLicenseTermsId);
        }
        Licensing.LicensingConfig memory lct = _getLicensingConfig(ipId, groupLicenseTemplate, groupLicenseTermsId);
        if (lct.disabled) {
            revert Errors.LicenseRegistry__IpLicenseDisabled(ipId, groupLicenseTemplate, groupLicenseTermsId);
        }
        if (lct.expectGroupRewardPool == address(0)) {
            revert Errors.LicenseRegistry__IpExpectGroupRewardPoolNotSet(ipId);
        }
        if (lct.expectGroupRewardPool != address(groupRewardPool)) {
            revert Errors.LicenseRegistry__IpExpectGroupRewardPoolNotMatch(
                ipId,
                lct.expectGroupRewardPool,
                groupId,
                address(groupRewardPool)
            );
        }
        // IP must not have expiration time to be added to group
        if (_getExpireTime(ipId) != 0) {
            revert Errors.LicenseRegistry__CannotAddIpWithExpirationToGroup(ipId);
        }
        // ipId must have the same license config items with group IP
        Licensing.LicensingConfig memory groupLct = _getLicensingConfig(
            groupId,
            groupLicenseTemplate,
            groupLicenseTermsId
        );

        // minting fee must be the same
        if (lct.mintingFee != groupLct.mintingFee) {
            revert Errors.LicenseRegistry__IpMintingFeeNotMatchWithGroup(ipId, lct.mintingFee, groupLct.mintingFee);
        }
        // hook must be the same
        if (lct.licensingHook != groupLct.licensingHook) {
            revert Errors.LicenseRegistry__IpLicensingHookNotMatchWithGroup(
                ipId,
                lct.licensingHook,
                groupLct.licensingHook
            );
        }
        // hook data must be the same
        if (
            lct.hookData.length != groupLct.hookData.length || keccak256(lct.hookData) != keccak256(groupLct.hookData)
        ) {
            revert Errors.LicenseRegistry__IpLicensingHookDataNotMatchWithGroup(ipId, lct.hookData, groupLct.hookData);
        }
        // group commercial revenue share must be greater than or equal to IP commercial revenue share
        if (groupLct.commercialRevShare < lct.commercialRevShare) {
            revert Errors.LicenseRegistry__GroupIpCommercialRevShareConfigMustNotLessThanIp(
                ipId,
                lct.commercialRevShare,
                groupLct.commercialRevShare
            );
        }

        ipLicensingConfig = lct;
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
        return _hasDerivativeIps(parentIpId);
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
        uint256 length = $.attachedLicenseTerms[ipId].length();
        if (index >= length) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(ipId, index, length);
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
        (bool success, bytes memory returnData) = _staticcallIpGraph(
            abi.encodeWithSignature("getParentIps(address)", childIpId),
            abi.encodeWithSignature("getParentIpsExt(address)", childIpId)
        );

        if (!success) revert Errors.LicenseRegistry__CallFailed();
        address[] memory parentIps = abi.decode(returnData, (address[]));
        if (index >= parentIps.length) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(childIpId, index, parentIps.length);
        }
        parentIpId = parentIps[index];
    }

    function isParentIp(address parentIpId, address childIpId) external view returns (bool) {
        (bool success, bytes memory returnData) = _staticcallIpGraph(
            abi.encodeWithSignature("hasParentIp(address,address)", childIpId, parentIpId),
            abi.encodeWithSignature("hasParentIpExt(address,address)", childIpId, parentIpId)
        );

        if (!success) revert Errors.LicenseRegistry__CallFailed();
        return (abi.decode(returnData, (bool)));
    }

    /// @notice Gets the count of parent IPs.
    /// @param childIpId The address of the childIP.
    /// @return The count o parent IPs.
    function getParentIpCount(address childIpId) external view returns (uint256) {
        (bool success, bytes memory returnData) = _staticcallIpGraph(
            abi.encodeWithSignature("getParentIpsCount(address)", childIpId),
            abi.encodeWithSignature("getParentIpsCountExt(address)", childIpId)
        );

        if (!success) revert Errors.LicenseRegistry__CallFailed();
        return abi.decode(returnData, (uint256));
    }

    /// @notice Gets the count of ancestors IPs
    /// @param ipId The ID of IP asset
    function getAncestorsCount(address ipId) external returns (uint256) {
        return _getAncestorIpsCount(ipId);
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

    /// @notice Checks if the license terms are the default license terms.
    function isDefaultLicense(address licenseTemplate, uint256 licenseTermsId) external view returns (bool) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        return $.defaultLicenseTemplate == licenseTemplate && $.defaultLicenseTermsId == licenseTermsId;
    }
    /// @notice Returns the license terms through which a child IP links to a parent IP.
    /// @param childIpId The address of the child IP.
    /// @param parentIpId The address of the parent IP.
    /// @return licenseTemplate The address of the license template.
    /// @return licenseTermsId The ID of the license terms.
    function getParentLicenseTerms(
        address childIpId,
        address parentIpId
    ) external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        return (_getLicenseTemplate(parentIpId), $.parentLicenseTerms[childIpId][parentIpId]);
    }

    /// @notice Return the Royalty percentage of the license terms of the IP.
    /// There are 2 places to get the royalty percentage: license terms, LicenseConfig
    /// The order of priority is LicenseConfig  > license terms
    /// @param ipId The address of the IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return royaltyPercent The Royalty percentage 100% is 100_000_000.
    function getRoyaltyPercent(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (uint32 royaltyPercent) {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        (, royaltyPercent, , ) = lct.getRoyaltyPolicy(licenseTermsId);
        Licensing.LicensingConfig memory lsc = _getLicensingConfig(ipId, licenseTemplate, licenseTermsId);
        if (lsc.isSet && lsc.commercialRevShare > 0) {
            royaltyPercent = lsc.commercialRevShare;
        }
    }

    /// @dev verify the child IP can be registered as a derivative of the parent IP
    /// @param parentIpId The address of the parent IP
    /// @param childIpId The address of the child IP
    /// @param licenseTemplate The address of the license template where the license terms are created
    /// @param licenseTermsId The license terms the child IP is registered with
    /// @param isUsingLicenseToken Whether the child IP is registered with license tokens
    function _verifyDerivativeFromParent(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bool isUsingLicenseToken
    ) internal view {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        // group IP should not has parent IP
        if (GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(childIpId)) {
            revert Errors.LicenseRegistry__GroupCannotHasParentIp(childIpId);
        }
        // revert if the parent IP is empty group IP
        if (
            GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(parentIpId) &&
            GROUP_IP_ASSET_REGISTRY.totalMembers(parentIpId) == 0
        ) {
            revert Errors.LicenseRegistry__ParentIpIsEmptyGroup(parentIpId);
        }
        if (DISPUTE_MODULE.isIpTagged(parentIpId)) {
            revert Errors.LicenseRegistry__ParentIpTagged(parentIpId);
        }
        if (childIpId == parentIpId) {
            revert Errors.LicenseRegistry__DerivativeIsParent(childIpId);
        }
        if (_isExpiredNow(parentIpId)) {
            revert Errors.LicenseRegistry__ParentIpExpired(parentIpId);
        }
        // childIp can only register with the license terms attached to the parent IP
        address pLicenseTemplate = _getLicenseTemplate(parentIpId);
        if (
            (isUsingLicenseToken && pLicenseTemplate != address(0) && pLicenseTemplate != licenseTemplate) ||
            (!isUsingLicenseToken && pLicenseTemplate != licenseTemplate)
        ) {
            revert Errors.LicenseRegistry__ParentIpUnmatchedLicenseTemplate(parentIpId, licenseTemplate);
        }
        if (!isUsingLicenseToken && !$.attachedLicenseTerms[parentIpId].contains(licenseTermsId)) {
            revert Errors.LicenseRegistry__ParentIpHasNoLicenseTerms(parentIpId, licenseTermsId);
        }
    }

    /// @dev return the license template attached an IP,
    function _getLicenseTemplate(address ipId) internal view returns (address licenseTemplate) {
        licenseTemplate = _getLicenseRegistryStorage().licenseTemplates[ipId];
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

    function _staticcallIpGraph(
        bytes memory internalFunc,
        bytes memory externalFunc
    ) internal view returns (bool, bytes memory) {
        bytes memory callData = IP_GRAPH_ACL.isInternalAccess() ? internalFunc : externalFunc;
        (bool success, bytes memory returnData) = IP_GRAPH.staticcall(callData);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        return (success, returnData);
    }

    function _callIpGraph(bytes memory internalFunc, bytes memory externalFunc) internal returns (bool, bytes memory) {
        bytes memory callData = IP_GRAPH_ACL.isInternalAccess() ? internalFunc : externalFunc;
        (bool success, bytes memory returnData) = IP_GRAPH.call(callData);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }
        return (success, returnData);
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
        (bool success, bytes memory returnData) = _staticcallIpGraph(
            abi.encodeWithSignature("getParentIpsCount(address)", childIpId),
            abi.encodeWithSignature("getParentIpsCountExt(address)", childIpId)
        );

        if (!success) revert Errors.LicenseRegistry__CallFailed();
        return abi.decode(returnData, (uint256)) > 0;
    }

    /// @dev Returns the count of ancestors for the given IP asset
    /// @param ipId The ID of the IP asset
    /// @return The number of ancestors
    function _getAncestorIpsCount(address ipId) internal returns (uint256) {
        (bool success, bytes memory returnData) = _callIpGraph(
            abi.encodeWithSignature("getAncestorIpsCount(address)", ipId),
            abi.encodeWithSignature("getAncestorIpsCountExt(address)", ipId)
        );
        if (!success) revert Errors.RoyaltyModule__CallFailed();
        return abi.decode(returnData, (uint256));
    }

    /// @dev Retrieves the minting license configuration for a given license terms of the IP.
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
        return
            Licensing.LicensingConfig({
                isSet: false,
                mintingFee: 0,
                licensingHook: address(0),
                hookData: "",
                commercialRevShare: 0,
                disabled: false,
                expectMinimumGroupRewardShare: 0,
                expectGroupRewardPool: address(0)
            });
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

    /// @notice Checks if an IP has derivative IPs.
    /// @param parentIpId The address of the IP to check.
    /// @return Whether the IP has derivative IPs.
    function _hasDerivativeIps(address parentIpId) internal view returns (bool) {
        return _getLicenseRegistryStorage().childIps[parentIpId].length() > 0;
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
