// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ILicenseRegistryV2 } from "../interfaces/registries/ILicenseRegistryV2.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { IDisputeModule } from "../interfaces/modules/dispute/IDisputeModule.sol";
import { Errors } from "../lib/Errors.sol";
import { Licensing } from "../lib/Licensing.sol";
import { GovernableUpgradeable } from "../governance/GovernableUpgradeable.sol";
import { ILicenseTemplate } from "contracts/interfaces/modules/licensing/ILicenseTemplate.sol";

/// @title LicenseRegistry aka LNFT
/// @notice Registry of License NFTs, which represent licenses granted by IP ID licensors to create derivative IPs.
contract LicenseRegistryV2 is ILicenseRegistryV2, GovernableUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Storage of the LicenseRegistry
    /// @param licensingModule Returns the canonical protocol-wide LicensingModule
    /// @param disputeModule Returns the canonical protocol-wide DisputeModule
    /// @custom:storage-location erc7201:story-protocol.LicenseRegistry
    struct LicenseRegistryStorage {
        ILicensingModule licensingModule;
        IDisputeModule disputeModule;
        address defaultLicenseTemplate;
        uint256 defaultLicenseTermsId;
        mapping(address => bool) registeredLicenseTemplates;
        mapping(address => bool) registeredRoyaltyPolicies;
        mapping(address => bool) registeredCurrencyTokens;
        mapping(address derivativeIpId => EnumerableSet.AddressSet originalIpIds) originalIps;
        mapping(address originalIpId => EnumerableSet.AddressSet derivativeIpIds) derivativeIps;
        mapping(address ipId => EnumerableSet.UintSet licenseTermsIds) attachedLicenseTerms;
        mapping(address ipId => address licenseTemplate) licenseTemplates;
        mapping(address ipId => uint256) expireTimes;
        mapping(bytes32 ipLicenseHash => Licensing.MintingLicenseSpec mintingLicenseSpec) mintingLicenseSpecs;
        mapping(address ipId => Licensing.MintingLicenseSpec mintingLicenseSpec) mintingLicenseSpecsForAll;
    }

    // TODO: update the storage location
    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicenseRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseRegistryStorageLocation =
        0x5ed898e10dedf257f39672a55146f3fecade9da16f4ff022557924a10d60a900;

    modifier onlyLicensingModule() {
        if (msg.sender != address(_getLicenseRegistryStorage().licensingModule)) {
            revert Errors.LicenseRegistry__CallerNotLicensingModule();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param governance The address of the governance contract
    function initialize(address governance) public initializer {
        __GovernableUpgradeable_init(governance);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the DisputeModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newDisputeModule The address of the DisputeModule
    function setDisputeModule(address newDisputeModule) external onlyProtocolAdmin {
        if (newDisputeModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroDisputeModule();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.disputeModule = IDisputeModule(newDisputeModule);
    }

    /// @dev Sets the LicensingModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newLicensingModule The address of the LicensingModule
    function setLicensingModule(address newLicensingModule) external onlyProtocolAdmin {
        if (newLicensingModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroLicensingModule();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.licensingModule = ILicensingModule(newLicensingModule);
    }

    function setDefaultLicenseTerms(address newLicenseTemplate, uint256 newLicenseTermsId) external onlyProtocolAdmin {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.defaultLicenseTemplate = newLicenseTemplate;
        $.defaultLicenseTermsId = newLicenseTermsId;
    }

    function registerLicenseTemplate(address licenseTemplate) external onlyProtocolAdmin {
        if (licenseTemplate.supportsInterface(type(ILicenseTemplate).interfaceId)) {
            revert Errors.LicenseRegistry__NotLicenseTemplate(licenseTemplate);
        }
        _getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate] = true;
        emit LicenseTemplateRegistered(licenseTemplate);
    }

    function registerRoyaltyPolicy(address royaltyPolicy) external onlyProtocolAdmin {
        _getLicenseRegistryStorage().registeredRoyaltyPolicies[royaltyPolicy] = true;
        emit RoyaltyPolicyRegistered(royaltyPolicy);
    }

    function registerCurrencyToken(address token) external onlyProtocolAdmin {
        _getLicenseRegistryStorage().registeredCurrencyTokens[token] = true;
        emit CurrencyTokenRegistered(token);
    }

    function setExpireTime(address ipId, uint256 expireTime) external onlyLicensingModule {
        _setExpireTime(ipId, expireTime);
    }

    function setMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        Licensing.MintingLicenseSpec calldata mintingLicenseSpec
    ) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        $.mintingLicenseSpecs[_getHash(ipId, licenseTemplate, licenseTermsId)] = Licensing.MintingLicenseSpec({
            isSet: true,
            mintingFee: mintingLicenseSpec.mintingFee,
            mintingFeeModule: mintingLicenseSpec.mintingFeeModule,
            receiverCheckModule: mintingLicenseSpec.receiverCheckModule,
            receiverCheckData: mintingLicenseSpec.receiverCheckData
        });

        emit MintingLicenseSpecSet(ipId, licenseTemplate, licenseTermsId, mintingLicenseSpec);
    }

    function setMintingLicenseSpecForAll(
        address ipId,
        Licensing.MintingLicenseSpec calldata mintingLicenseSpec
    ) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.mintingLicenseSpecsForAll[ipId] = Licensing.MintingLicenseSpec({
            isSet: true,
            mintingFee: mintingLicenseSpec.mintingFee,
            mintingFeeModule: mintingLicenseSpec.mintingFeeModule,
            receiverCheckModule: mintingLicenseSpec.receiverCheckModule,
            receiverCheckData: mintingLicenseSpec.receiverCheckData
        });
        emit MintingLicenseSpecSetForAll(ipId, mintingLicenseSpec);
    }

    function attachLicenseTermsToIp(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external onlyLicensingModule {
        if (!_existsLicenseTerms(licenseTemplate, licenseTermsId)) {
            revert Errors.LicensingModule__LicenseTermsNotFound(licenseTemplate, licenseTermsId);
        }

        if (_isDerivativeIp(ipId)) {
            revert Errors.LicensingModule__DerivativesCannotAddLicenseTerms();
        }

        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.expireTimes[ipId] < block.timestamp) {
            revert Errors.LicenseRegistry__IpExpired(ipId);
        }
        $.attachedLicenseTerms[ipId].add(licenseTermsId);
    }

    // solhint-disable-next-line code-complexity
    function registerDerivativeIp(
        address derivativeIpId,
        address[] calldata originalIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) external onlyLicensingModule {
        if (originalIpIds.length == 0) {
            revert Errors.LicenseRegistry__NoOriginalIp();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.attachedLicenseTerms[derivativeIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense(derivativeIpId);
        }
        if ($.originalIps[derivativeIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeAlreadyRegistered(derivativeIpId);
        }

        for (uint256 i = 0; i < originalIpIds.length; i++) {
            if ($.disputeModule.isIpTagged(originalIpIds[i])) {
                revert Errors.LicenseRegistry__OriginalIpTagged(originalIpIds[i]);
            }
            if (derivativeIpId == originalIpIds[i]) {
                revert Errors.LicenseRegistry__DerivativeIsOriginal(derivativeIpId);
            }
            if ($.expireTimes[originalIpIds[i]] < block.timestamp) {
                revert Errors.LicenseRegistry__OriginalIpExpired(originalIpIds[i]);
            }
            // derivativeIp can only register with default license terms or the same license terms as the original IP
            if ($.defaultLicenseTemplate != licenseTemplate || $.defaultLicenseTermsId != licenseTermsIds[i]) {
                if ($.licenseTemplates[originalIpIds[i]] != licenseTemplate) {
                    revert Errors.LicenseRegistry__OriginalIpUnmachedLicenseTemplate(originalIpIds[i], licenseTemplate);
                }
                if (!$.attachedLicenseTerms[originalIpIds[i]].contains(licenseTermsIds[i])) {
                    revert Errors.LicenseRegistry__OriginalIpHasNoLicenseTerms(originalIpIds[i], licenseTermsIds[i]);
                }
            }
            $.originalIps[derivativeIpId].add(originalIpIds[i]);
            $.derivativeIps[originalIpIds[i]].add(derivativeIpId);
            $.attachedLicenseTerms[derivativeIpId].add(licenseTermsIds[i]);
        }

        $.licenseTemplates[derivativeIpId] = licenseTemplate;
        _setExpireTime(
            derivativeIpId,
            ILicenseTemplate(licenseTemplate).getEarlierExpireTime(block.timestamp, licenseTermsIds)
        );
    }

    function verifyMintLicenseToken(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bool isMintedByIpOwner
    ) external view returns (Licensing.MintingLicenseSpec memory) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.expireTimes[originalIpId] < block.timestamp) {
            revert Errors.LicenseRegistry__OriginalIpExpired(originalIpId);
        }
        if (isMintedByIpOwner) {
            if (!_existsLicenseTerms(licenseTemplate, licenseTermsId)) {
                revert Errors.LicenseRegistry__LicenseTermsNotExists(licenseTemplate, licenseTermsId);
            }
        } else if (!_hasIpAttachedLicenseTerms(originalIpId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__OriginalIpHasNoLicenseTerms(originalIpId, licenseTermsId);
        }
        return _getMintingLicenseSpec(originalIpId, licenseTemplate, licenseTermsId);
    }

    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool) {
        return _getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate];
    }

    function isRegisteredRoyaltyPolicy(address royaltyPolicy) external view returns (bool) {
        return _getLicenseRegistryStorage().registeredRoyaltyPolicies[royaltyPolicy];
    }

    function isRegisteredCurrencyToken(address token) external view returns (bool) {
        return _getLicenseRegistryStorage().registeredCurrencyTokens[token];
    }

    function isDerivativeIp(address derivativeIpId) external view returns (bool) {
        return _isDerivativeIp(derivativeIpId);
    }

    function hasDerivativeIps(address originalIpId) external view returns (bool) {
        return _getLicenseRegistryStorage().derivativeIps[originalIpId].length() > 0;
    }

    function existsLicenseTerms(address licenseTemplate, uint256 licenseTermsId) external view returns (bool) {
        return _existsLicenseTerms(licenseTemplate, licenseTermsId);
    }

    function hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (bool) {
        return _hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId);
    }

    function getAttachedLicenseTerms(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.attachedLicenseTerms[ipId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(ipId, index);
        }
        licenseTemplate = $.licenseTemplates[ipId];
        licenseTermsId = $.attachedLicenseTerms[ipId].at(index);
    }

    function getAttachedLicenseTermsCount(address ipId) external view returns (uint256) {
        return _getLicenseRegistryStorage().attachedLicenseTerms[ipId].length();
    }

    function getMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (Licensing.MintingLicenseSpec memory) {
        return _getMintingLicenseSpec(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Returns the canonical protocol-wide LicensingModule
    function licensingModule() external view returns (ILicensingModule) {
        return _getLicenseRegistryStorage().licensingModule;
    }

    /// @notice Returns the canonical protocol-wide DisputeModule
    function disputeModule() external view returns (IDisputeModule) {
        return _getLicenseRegistryStorage().disputeModule;
    }

    function getExpireTime(address ipId) external view returns (uint256) {
        return _getLicenseRegistryStorage().expireTimes[ipId];
    }

    function getDefaultLicenseTerms() external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        return ($.defaultLicenseTemplate, $.defaultLicenseTermsId);
    }

    function _setExpireTime(address ipId, uint256 expireTime) internal {
        _getLicenseRegistryStorage().expireTimes[ipId] = expireTime;
        emit ExpireTimeSet(ipId, expireTime);
    }

    function _isDerivativeIp(address derivativeIpId) internal view returns (bool) {
        return _getLicenseRegistryStorage().originalIps[derivativeIpId].length() > 0;
    }

    function _getMintingLicenseSpec(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (Licensing.MintingLicenseSpec memory) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        if ($.mintingLicenseSpecs[_getHash(ipId, licenseTemplate, licenseTermsId)].isSet) {
            return $.mintingLicenseSpecs[_getHash(ipId, licenseTemplate, licenseTermsId)];
        }
        return $.mintingLicenseSpecsForAll[ipId];
    }

    function _getHash(address ipId, address licenseTemplate, uint256 licenseTermsId) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(ipId, licenseTemplate, licenseTermsId));
    }

    function _hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (bool) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.defaultLicenseTemplate == licenseTemplate && $.defaultLicenseTermsId == licenseTermsId) return true;
        return $.licenseTemplates[ipId] == licenseTemplate && $.attachedLicenseTerms[ipId].contains(licenseTermsId);
    }

    function _existsLicenseTerms(address licenseTemplate, uint256 licenseTermsId) internal view returns (bool) {
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

    /// @dev Hook to authorize the upgrade according to UUPSUgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyProtocolAdmin {}
}
