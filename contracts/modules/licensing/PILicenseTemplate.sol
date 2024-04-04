// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// contracts
import { IHookModule } from "../../interfaces/modules/base/IHookModule.sol";
import { ILicenseRegistryV2 } from "../../interfaces/registries/ILicenseRegistryV2.sol";
import { PILicenseTemplateErrors } from "../../lib/PILicenseTemplateErrors.sol";
import { IPILicenseTemplate, PILTerms } from "../../interfaces/modules/licensing/IPILicenseTemplate.sol";
import { BaseLicenseTemplate } from "../../modules/licensing/BaseLicenseTemplate.sol";
import { LicensorApprovalCheckerV2 } from "../../modules/licensing/parameter-helpers/LicensorApprovalCheckerV2.sol";

/// @title PILicenseTemplate
contract PILicenseTemplate is
    BaseLicenseTemplate,
    IPILicenseTemplate,
    LicensorApprovalCheckerV2,
    ReentrancyGuardUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;

    /// @custom:storage-location erc7201:story-protocol.PILicenseTemplate
    struct PILicenseTemplateStorage {
        mapping(uint256 licenseTermsId => PILTerms) licenseTerms;
        mapping(bytes32 licenseTermsHash => uint256 licenseTermsId) hashedLicenseTerms;
        uint256 licenseTermsCounter;
    }

    ILicenseRegistryV2 public immutable LICENSE_REGISTRY;

    // TODO: update storage location
    // keccak256(abi.encode(uint256(keccak256("story-protocol.BaseLicenseTemplate")) - 1))
    // & ~bytes32(uint256(0xff));
    bytes32 private constant PILicenseTemplateStorageLocation =
        0xa55803740ac9329334ad7b6cde0ec056cc3ba32125b59c579552512bed001f00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address licenseRegistry,
        address licenseNFT
    ) LicensorApprovalCheckerV2(accessController, ipAccountRegistry, licenseNFT) {
        LICENSE_REGISTRY = ILicenseRegistryV2(licenseRegistry);
        _disableInitializers();
    }

    function initialize(string memory name, string memory metadataURI) external initializer {
        __BaseLicenseTemplate_init(name, metadataURI);
        __ReentrancyGuard_init();
    }

    function registerLicenseTerms(PILTerms calldata terms) external nonReentrant returns (uint256 id) {
        if (terms.royaltyPolicy != address(0) && !LICENSE_REGISTRY.isRegisteredRoyaltyPolicy(terms.royaltyPolicy)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyNotWhitelisted();
        }

        if (terms.currency != address(0) && !LICENSE_REGISTRY.isRegisteredCurrencyToken(terms.currency)) {
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

    function exists(uint256 licenseTermsId) external view override returns (bool) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return licenseTermsId < $.licenseTermsCounter;
    }

    function verifyMintLicenseToken(
        uint256 licenseTermsId,
        address licensee,
        address licensorIpId,
        uint256 mintAmount
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

    function verifyRegisterDerivative(
        address derivativeIpId,
        address originalIpId,
        uint256 licenseTermsId,
        address licensee
    ) external override returns (bool) {
        return _verifyRegisterDerivative(derivativeIpId, originalIpId, licenseTermsId, licensee);
    }

    function verifyCompatibleLicenses(uint256[] calldata licenseTermsIds) external view override returns (bool) {
        return _verifyCompatibleLicenseTerms(licenseTermsIds);
    }

    function verifyRegisterDerivativeForAll(
        address derivativeIpId,
        address[] calldata originalIpIds,
        uint256[] calldata licenseTermsIds,
        address derivativeIpOwner
    ) external override returns (bool) {
        if (!_verifyCompatibleLicenseTerms(licenseTermsIds)) {
            return false;
        }
        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            if (!_verifyRegisterDerivative(derivativeIpId, originalIpIds[i], licenseTermsIds[i], derivativeIpOwner)) {
                return false;
            }
        }
        return true;
    }

    function getRoyaltyPolicy(
        uint256 licenseId
    ) external view returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingFee, address currency) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseId];
        return (terms.royaltyPolicy, abi.encode(terms.commercialRevShare), terms.mintingFee, terms.currency);
    }

    function isTransferable(uint256 licenseId) external view override returns (bool) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return $.licenseTerms[licenseId].transferable;
    }

    function getEarlierExpireTime(
        uint256 start,
        uint256[] calldata licenseTermsIds
    ) external view override returns (uint) {
        if (licenseTermsIds.length == 0) {
            return 0;
        }
        uint expireTime = _getExpireTime(start, licenseTermsIds[0]);
        for (uint i = 1; i < licenseTermsIds.length; i++) {
            uint newExpireTime = _getExpireTime(start, licenseTermsIds[i]);
            if (newExpireTime < expireTime) {
                expireTime = newExpireTime;
            }
        }
        return expireTime;
    }

    function getExpireTime(uint256 start, uint256 licenseTermsId) external view returns (uint) {
        return _getExpireTime(start, licenseTermsId);
    }

    function getLicenseTermsId(PILTerms calldata terms) external view returns (uint256 licenseTermsId) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        bytes32 licenseTermsHash = keccak256(abi.encode(terms));
        return $.hashedLicenseTerms[licenseTermsHash];
    }

    function totalRegisteredLicenseTerms() external view returns (uint256) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        return $.licenseTermsCounter;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(BaseLicenseTemplate, IERC165) returns (bool) {
        return interfaceId == type(IPILicenseTemplate).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Returns the stringified JSON policy data for the LicenseRegistry.uri(uint256) method.
    /// @dev Must return OpenSea standard compliant metadata.
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
                terms.currency == address(0) ? "Native Token" : terms.currency.toHexString(),
                '"},',
                // Skip transferable, it's already added in the common attributes by the LicenseRegistry.
                // Should be managed by the LicenseRegistry, not the PFM.
                _policyCommercialTraitsToJson(terms),
                _policyDerivativeTraitsToJson(terms)
            )
        );

        // NOTE: (above) last trait added by PFM should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of PIL policy into a JSON string for OpenSea
    function _policyCommercialTraitsToJson(PILTerms memory terms) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RNFT_SUPPLY = 1000 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
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

    /// @dev Encodes the derivative traits of PIL policy into a JSON string for OpenSea
    function _policyDerivativeTraitsToJson(PILTerms memory terms) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RNFT_SUPPLY = 1000 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
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

    /// @notice Checks the configuration of derivative parameters and throws if the policy is not compliant
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

    function _verifyRegisterDerivative(
        address derivativeIpId,
        address originalIpId,
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
        if (terms.derivativesApproval && !isDerivativeApproved(licenseTermsId, derivativeIpId)) {
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

    function _getExpireTime(uint256 start, uint256 licenseTermsId) internal view returns (uint) {
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        PILTerms memory terms = $.licenseTerms[licenseTermsId];
        if (terms.expiration == 0) {
            return 0;
        }
        return start + terms.expiration;
    }

    /// @dev Returns the storage struct of PILicenseTemplate.
    function _getPILicenseTemplateStorage() private pure returns (PILicenseTemplateStorage storage $) {
        assembly {
            $.slot := PILicenseTemplateStorageLocation
        }
    }
}
