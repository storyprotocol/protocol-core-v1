// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// contracts
import { Errors } from "../../lib/Errors.sol";
import { IHookModule } from "../../interfaces/modules/base/IHookModule.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { PILicenseTemplateErrors } from "../../lib/PILicenseTemplateErrors.sol";
import { IPILicenseTemplate, PILTerms } from "../../interfaces/modules/licensing/IPILicenseTemplate.sol";
import { BaseLicenseTemplateUpgradeable } from "../../modules/licensing/BaseLicenseTemplateUpgradeable.sol";
import { LicensorApprovalChecker } from "../../modules/licensing/parameter-helpers/LicensorApprovalChecker.sol";

/// @title PILicenseTemplate
contract PILicenseTemplate is
    BaseLicenseTemplateUpgradeable,
    IPILicenseTemplate,
    LicensorApprovalChecker,
    AccessManagedUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;

    /// @dev Storage structure for the PILicenseTemplate
    /// @custom:storage-location erc7201:story-protocol.PILicenseTemplate
    struct PILicenseTemplateStorage {
        mapping(uint256 licenseTermsId => PILTerms) licenseTerms;
        mapping(bytes32 licenseTermsHash => uint256 licenseTermsId) hashedLicenseTerms;
        uint256 licenseTermsCounter;
    }

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.PILicenseTemplate")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant PILicenseTemplateStorageLocation =
        0xc6c6991297bc120d0383f0017fab72b8ca34fd4849ed6478dbaac67a33c3a700;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address licenseRegistry,
        address royaltyModule
    ) LicensorApprovalChecker(accessController, ipAccountRegistry) {
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    /// @param name The name of the license template
    /// @param metadataURI The URL to the off chain metadata
    function initialize(address accessManager, string memory name, string memory metadataURI) external initializer {
        if (accessManager == address(0)) {
            revert Errors.PILicenseTemplate__ZeroAccessManager();
        }
        __BaseLicenseTemplate_init(name, metadataURI);
        __AccessManaged_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Registers new license terms and return the ID of the newly registered license terms.
    /// @dev The license terms are hashed and the hash is used to check if the terms are already registered.
    /// It will return existing ID if the terms are already registered.
    /// @param terms The PILTerms to register.
    /// @return id The ID of the newly registered license terms.
    function registerLicenseTerms(PILTerms calldata terms) external nonReentrant returns (uint256 id) {
        if (terms.royaltyPolicy != address(0) && !ROYALTY_MODULE.isWhitelistedRoyaltyPolicy(terms.royaltyPolicy)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyNotWhitelisted();
        }

        if (terms.currency != address(0) && !ROYALTY_MODULE.isWhitelistedRoyaltyToken(terms.currency)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__CurrencyTokenNotWhitelisted();
        }

        if (terms.royaltyPolicy != address(0) && terms.currency == address(0)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyRequiresCurrencyToken();
        }

        _verifyCommercialUse(terms);
        _verifyDerivatives(terms);

        bytes32 hashedLicense = keccak256(abi.encode(terms));
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        id = $.hashedLicenseTerms[hashedLicense];
        if (id != 0) {
            return id;
        }
        id = ++$.licenseTermsCounter;
        $.licenseTerms[id] = terms;
        $.hashedLicenseTerms[hashedLicense] = id;

        emit LicenseTermsRegistered(id, address(this), abi.encode(terms));
    }

    /// @notice Checks if a license terms exists.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms exists, false otherwise.
    function exists(uint256 licenseTermsId) external view override returns (bool) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return licenseTermsId <= $.licenseTermsCounter;
    }

    /// @notice Verifies the minting of a license token.
    /// @dev the function will be called by the LicensingModule when minting a license token to
    /// verify the minting is whether allowed by the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee who will receive the license token.
    /// @param licensorIpId The IP ID of the licensor who attached the license terms minting the license token.
    /// @return True if the minting is verified, false otherwise.
    function verifyMintLicenseToken(
        uint256 licenseTermsId,
        address licensee,
        address licensorIpId,
        uint256
    ) external override nonReentrant returns (bool) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseTermsId];
        // If the policy defines no reciprocal derivatives are allowed (no derivatives of derivatives),
        // and we are mintingFromADerivative we don't allow minting
        if (LICENSE_REGISTRY.isDerivativeIp(licensorIpId)) {
            if (!LICENSE_REGISTRY.hasIpAttachedLicenseTerms(licensorIpId, address(this), licenseTermsId)) {
                return false;
            }
            if (!terms.derivativesReciprocal) {
                return false;
            }
        }

        if (terms.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(terms.commercializerChecker).verify(licensee, terms.commercializerCheckerData)) {
                return false;
            }
        }

        return true;
    }

    /// @notice Verifies the registration of a derivative.
    /// @dev This function is invoked by the LicensingModule during the registration of a derivative work
    //// to ensure compliance with the parent IP's licensing terms.
    /// It verifies whether the derivative's registration is permitted under those terms.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpId The IP ID of the parent.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivative(
        address childIpId,
        address parentIpId,
        uint256 licenseTermsId,
        address licensee
    ) external override returns (bool) {
        return _verifyRegisterDerivative(childIpId, parentIpId, licenseTermsId, licensee);
    }

    /// @notice Verifies if the licenses are compatible.
    /// @dev This function is called by the LicensingModule to verify license compatibility
    /// when registering a derivative IP to multiple parent IPs.
    /// It ensures that the licenses of all parent IPs are compatible with each other during the registration process.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return True if the licenses are compatible, false otherwise.
    function verifyCompatibleLicenses(uint256[] calldata licenseTermsIds) external view override returns (bool) {
        return _verifyCompatibleLicenseTerms(licenseTermsIds);
    }

    /// @notice Verifies the registration of a derivative for all parent IPs.
    /// @dev This function is called by the LicensingModule to verify licenses for registering a derivative IP
    /// to multiple parent IPs.
    /// the function will verify the derivative for each parent IP's license and
    /// also verify all licenses are compatible.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpIds The IP IDs of the parents.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param childIpOwner The address of the derivative IP owner.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivativeForAllParents(
        address childIpId,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds,
        address childIpOwner
    ) external override returns (bool) {
        if (!_verifyCompatibleLicenseTerms(licenseTermsIds)) {
            return false;
        }
        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            if (!_verifyRegisterDerivative(childIpId, parentIpIds[i], licenseTermsIds[i], childIpOwner)) {
                return false;
            }
        }
        return true;
    }

    /// @notice Returns the royalty policy of a license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return royaltyPolicy The address of the royalty policy specified for the license terms.
    /// @return royaltyData The data of the royalty policy.
    /// @return mintingFee The fee for minting a license.
    /// @return currency The address of the ERC20 token, used for minting license fee and royalties.
    /// the currency token will used for pay for license token minting fee and royalties.
    function getRoyaltyPolicy(
        uint256 licenseTermsId
    ) external view returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingFee, address currency) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseTermsId];
        return (terms.royaltyPolicy, abi.encode(terms.commercialRevShare), terms.mintingFee, terms.currency);
    }

    /// @notice Checks if a license terms is transferable.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms is transferable, false otherwise.
    function isLicenseTransferable(uint256 licenseTermsId) external view override returns (bool) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return $.licenseTerms[licenseTermsId].transferable;
    }

    /// @notice Returns the earliest expiration time among the given license terms.
    /// @param start The start time.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return The earliest expiration time.
    function getEarlierExpireTime(
        uint256[] calldata licenseTermsIds,
        uint256 start
    ) external view override returns (uint256) {
        if (licenseTermsIds.length == 0) {
            return 0;
        }
        uint expireTime = _getExpireTime(licenseTermsIds[0], start);
        for (uint i = 1; i < licenseTermsIds.length; i++) {
            uint newExpireTime = _getExpireTime(licenseTermsIds[i], start);
            if (newExpireTime < expireTime || expireTime == 0) {
                expireTime = newExpireTime;
            }
        }
        return expireTime;
    }

    /// @notice Returns the expiration time of a license terms.
    /// @param start The start time.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The expiration time.
    function getExpireTime(uint256 licenseTermsId, uint256 start) external view returns (uint256) {
        return _getExpireTime(licenseTermsId, start);
    }

    /// @notice Gets the ID of the given license terms.
    /// @param terms The PILTerms to get the ID for.
    /// @return selectedLicenseTermsId The ID of the given license terms.
    function getLicenseTermsId(PILTerms calldata terms) external view returns (uint256 selectedLicenseTermsId) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        bytes32 licenseTermsHash = keccak256(abi.encode(terms));
        return $.hashedLicenseTerms[licenseTermsHash];
    }

    /// @notice Gets license terms of the given ID.
    /// @param selectedLicenseTermsId The ID of the license terms.
    /// @return terms The PILTerms associate with the given ID.
    function getLicenseTerms(uint256 selectedLicenseTermsId) external view returns (PILTerms memory terms) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return $.licenseTerms[selectedLicenseTermsId];
    }

    /// @notice Returns the total number of registered license terms.
    /// @return The total number of registered license terms.
    function totalRegisteredLicenseTerms() external view returns (uint256) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return $.licenseTermsCounter;
    }

    /// @notice checks the contract whether supports the given interface.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(BaseLicenseTemplateUpgradeable, IERC165) returns (bool) {
        return interfaceId == type(IPILicenseTemplate).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Converts the license terms to a JSON string which will be part of the metadata of license token.
    /// @dev Must return OpenSea standard compliant metadata.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The JSON string of the license terms, follow the OpenSea metadata standard.
    function toJson(uint256 licenseTermsId) public view returns (string memory) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseTermsId];

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata.
        // **Attributions**
        string memory json = string(
            abi.encodePacked(
                '{"trait_type": "Expiration", "value": "',
                terms.expiration == 0 ? "never" : terms.expiration.toString(),
                '"},',
                '{"trait_type": "Currency", "value": "',
                terms.currency.toHexString(),
                '"},',
                // Skip transferable, it's already added in the common attributes by the LicenseRegistry.
                _policyCommercialTraitsToJson(terms),
                _policyDerivativeTraitsToJson(terms)
            )
        );

        // NOTE: (above) last trait added by LicenseTemplate should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of PIL policy into a JSON string for OpenSea
    function _policyCommercialTraitsToJson(PILTerms memory terms) internal pure returns (string memory) {
        /* solhint-disable */
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Commercial Use", "value": "',
                    terms.commercialUse ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Attribution", "value": "',
                    terms.commercialAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": ',
                    terms.commercialRevShare.toString(),
                    "},",
                    '{"trait_type": "Commercial Revenue Celling", "value": ',
                    terms.commercialRevCelling.toString(),
                    "},",
                    '{"trait_type": "Commercializer Check", "value": "',
                    terms.commercializerChecker.toHexString(),
                    // Skip on commercializerCheckerData as it's bytes as irrelevant for the user metadata
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Encodes the derivative traits of PILTerm into a JSON string for OpenSea
    function _policyDerivativeTraitsToJson(PILTerms memory terms) internal pure returns (string memory) {
        /* solhint-disable */
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Derivatives Allowed", "value": "',
                    terms.derivativesAllowed ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Attribution", "value": "',
                    terms.derivativesAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Revenue Celling", "value": ',
                    terms.derivativeRevCelling.toString(),
                    "},",
                    '{"trait_type": "Derivatives Approval", "value": "',
                    terms.derivativesApproval ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Reciprocal", "value": "',
                    terms.derivativesReciprocal ? "true" : "false",
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Checks the configuration of commercial use and throws if the policy is not compliant
    // solhint-disable-next-line code-complexity
    function _verifyCommercialUse(PILTerms calldata terms) internal view {
        if (!terms.commercialUse) {
            if (terms.commercialAttribution) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddAttribution();
            }
            if (terms.commercializerChecker != address(0)) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddCommercializers();
            }
            if (terms.commercialRevShare > 0) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRevShare();
            }
            if (terms.royaltyPolicy != address(0)) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy();
            }
        } else {
            if (terms.royaltyPolicy == address(0)) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired();
            }
            if (terms.commercializerChecker != address(0)) {
                if (!terms.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                    revert PILicenseTemplateErrors.PILicenseTemplate__CommercializerCheckerDoesNotSupportHook(
                        terms.commercializerChecker
                    );
                }
                IHookModule(terms.commercializerChecker).validateConfig(terms.commercializerCheckerData);
            }
        }
    }

    /// @dev notice Checks the configuration of derivative parameters and throws if the policy is not compliant
    function _verifyDerivatives(PILTerms calldata terms) internal pure {
        if (!terms.derivativesAllowed) {
            if (terms.derivativesAttribution) {
                revert PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddAttribution();
            }
            if (terms.derivativesApproval) {
                revert PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddApproval();
            }
            if (terms.derivativesReciprocal) {
                revert PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddReciprocal();
            }
        }
    }

    /// @dev Verifies derivative IP permitted by license terms during process of the registration of a derivative.
    function _verifyRegisterDerivative(
        address childIpId,
        address parentIpId,
        uint256 licenseTermsId,
        address licensee
    ) internal returns (bool) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseTermsId];

        if (!terms.derivativesAllowed) {
            return false;
        }

        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (terms.derivativesApproval && !isDerivativeApproved(parentIpId, licenseTermsId, childIpId)) {
            return false;
        }
        // Check if the commercializerChecker allows the link
        if (terms.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(terms.commercializerChecker).verify(licensee, terms.commercializerCheckerData)) {
                return false;
            }
        }
        return true;
    }

    /// @dev Verifies if the license terms are compatible.
    function _verifyCompatibleLicenseTerms(uint256[] calldata licenseTermsIds) internal view returns (bool) {
        if (licenseTermsIds.length < 2) {
            return true;
        }
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        bool commercial = $.licenseTerms[licenseTermsIds[0]].commercialUse;
        bool derivativesReciprocal = $.licenseTerms[licenseTermsIds[0]].derivativesReciprocal;
        for (uint256 i = 1; i < licenseTermsIds.length; i++) {
            PILTerms memory terms = $.licenseTerms[licenseTermsIds[i]];
            if (terms.commercialUse != commercial) {
                return false;
            }
            if (terms.derivativesReciprocal != derivativesReciprocal) {
                return false;
            }
        }
        return true;
    }

    /// @dev Calculate and returns the expiration time based given start time and license terms.
    function _getExpireTime(uint256 licenseTermsId, uint256 start) internal view returns (uint) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseTermsId];
        if (terms.expiration == 0) {
            return 0;
        }
        return start + terms.expiration;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @dev Returns the storage struct of PILicenseTemplate.
    function _getPILicenseTemplateStorage() private pure returns (PILicenseTemplateStorage storage $) {
        assembly {
            $.slot := PILicenseTemplateStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
