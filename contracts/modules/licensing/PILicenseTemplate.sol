// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// contracts
import { IHookModule } from "../../interfaces/modules/base/IHookModule.sol";
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "../../lib/Licensing.sol";
import { Errors } from "../../lib/Errors.sol";
import { PILFrameworkErrors } from "../../lib/PILFrameworkErrors.sol";
import { IPILicenseTemplate, License } from "../../interfaces/modules/licensing/IPILicenseTemplate.sol";
import { BaseLicenseTemplate } from "../../modules/licensing/BaseLicenseTemplate.sol";
import { LicensorApprovalChecker } from "../../modules/licensing/parameter-helpers/LicensorApprovalChecker.sol";
import {ISupportRoyalty} from "../../interfaces/modules/licensing/ISupportRoyaltyPolicy.sol";

/// @title PILicenseTemplate
/// @notice PIL Policy Framework Manager implements the PIL Policy Framework logic for encoding and decoding PIL
/// policies into the LicenseRegistry and verifying the licensing parameters for linking, minting, and transferring.
contract PILicenseTemplate is
    BaseLicenseTemplate,
    IPILicenseTemplate,
ISupportRoyalty,
    LicensorApprovalChecker,
    ReentrancyGuardUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;

    mapping(uint256 licenseId => License) public licenses;
    mapping(bytes32 licenseHash => uint256 licenseId) public hashedLicenses;
    uint256 public licenseCounter;

    /// Constructor
    /// @param accessController the address of the AccessController
    /// @param ipAccountRegistry the address of the IPAccountRegistry
    /// @param licensing the address of the LicensingModule
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address licenseRegistry
    ) LicensorApprovalChecker(accessController, ipAccountRegistry, licenseRegistry) {
        _disableInitializers();
    }

    function initialize(string memory name, string memory metadataURI) external initializer {
        __BaseLicenseTemplate_init(name, metadataURI);
        __ReentrancyGuard_init();
    }

    function registerLicense(License calldata license) external nonReentrant returns (uint256 licenseId) {
        if (
            license.royaltyPolicy != address(0) && !LICENSE_REGISTRY.isWhitelistedRoyaltyPolicy(license.royaltyPolicy)
        ) {
            revert Errors.PILicenseTemplate__RoyaltyPolicyNotWhitelisted();
        }

        if (license.currency != address(0) && !LICENSE_REGISTRY.isWhitelistedToken(license.currency)) {
            revert Errors.PILicenseTemplate__CurrencyTokenNotWhitelisted();
        }

        if (license.royaltyPolicy != address(0) && license.currency == address(0)) {
            revert Errors.PILicenseTemplate__RoyaltyPolicyRequiresCurrency();
        }

        _verifyCommercialUse(license);
        _verifyDerivatives(license);
        bytes32 hashedLicense = keccak256(abi.encode(license));
        licenseId = hashedLicenses[hashedLicense];
        if (licenseId != 0) {
            return licenseId;
        }
        licenseId = licenseCounter++;
        licenses[licenseId] = license;
        hashedLicenses[hashedLicense] = licenseId;

        emit LicenseRegistered(licenseId, address(this), abi.encode(license));
    }

    function exists(uint256 licenseId) external view override returns (bool) {
        return licenseId < licenseCounter;
    }

    function verifyMintLicenseToken(
        uint256 licenseId,
        address licensee,
        address licensorIpId,
        uint256 mintAmount
    ) external view override nonReentrant returns (bool) {
        License memory license = licenses[licenseId];
        // If the policy defines no reciprocal derivatives are allowed (no derivatives of derivatives),
        // and we are mintingFromADerivative we don't allow minting
        if (LICENSE_REGISTRY.isDerivativeIp(licensorIpId)) {
            if (!LICENSE_REGISTRY.hasIpAttachedLicense(licensorIpId, address(this), licenseId)) {
                return false;
            }
            if (!license.derivativesReciprocal) {
                return false;
            }
        }
        if (!license.derivativesReciprocal && ) {
            return false;
        }

        if (license.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(license.commercializerChecker).verify(licensee, license.commercializerCheckerData)) {
                return false;
            }
        }

        return true;
    }

    function verifyRegisterDerivative(
        uint256 licenseId,
        address licensee,
        address derivativeIpId,
        address originalIpId
    ) external view override returns (bool) {
        License memory license = licenses[licenseId];

        // Trying to burn a license to create a derivative, when the license doesn't allow derivatives.
        if (!license.derivativesAllowed) {
            return false;
        }

        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (license.derivativesApproval && !isDerivativeApproved(licenseId, derivativeIpId)) {
            return false;
        }
        // Check if the commercializerChecker allows the link
        if (license.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(license.commercializerChecker).verify(licensee, license.commercializerCheckerData)) {
                return false;
            }
        }
        return true;
    }

    function verifyCompatibleLicenses(uint256[] calldata licenseIds) external view override returns (bool) {
        if (licenseIds.length < 2) {
            return true;
        }
        bool commercial = licenses[licenseIds[0]].commercial;
        bool derivativesReciprocal = licenses[licenseIds[0]].derivativesReciprocal;
        //TODO: check royalty policy
        for (uint256 i = 1; i < licenseIds.length; i++) {
            License memory license = licenses[licenseIds[i]];
            if (license.commercial != commercial) {
                return false;
            }
            if (license.derivativesReciprocal != derivativesReciprocal) {
                return false;
            }
        }
        return true;
    }

    function getRoyaltyPolicy(
        uint256 licenseId
    ) external view returns (address royaltyPolicy, bytes memory royaltyData, address currency) {
        License memory license = licenses[licenseId];
        return (license.royaltyPolicy, abi.encode(license.commercialRevShare), license.mintingFee, license.currency);
    }
    function isTransferable(uint256 licenseId) external view override returns (bool) {
        return licenses[licenseId].transferable;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ISupportRoyalty).interfaceId ||
            interfaceId == type(IPILicenseTemplate).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Returns the stringified JSON policy data for the LicenseRegistry.uri(uint256) method.
    /// @dev Must return OpenSea standard compliant metadata.
    function getLicenseString(uint256 licenseId) public view returns (string memory) {
        License memory license = licenses[licenseId];

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata.
        // **Attributions**
        string memory json = string(
            abi.encodePacked(
                '{"trait_type": "Expiration", "value": "',
                license.expiration == 0 ? "never" : license.expiration.toString(),
                '"},',
                '{"trait_type": "Currency", "value": "',
                license.currency == address(0) ? "Native Token" : license.currency.toHexString(),
                '"},',
                // Skip transferable, it's already added in the common attributes by the LicenseRegistry.
                // Should be managed by the LicenseRegistry, not the PFM.
                _policyCommercialTraitsToJson(license),
                _policyDerivativeTraitsToJson(license)
            )
        );

        // NOTE: (above) last trait added by PFM should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of PIL policy into a JSON string for OpenSea
    /// @param policy The policy to encode
    function _policyCommercialTraitsToJson(License memory license) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RNFT_SUPPLY = 1000 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Commercial Use", "value": "',
                    license.commercialUse ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Attribution", "value": "',
                    license.commercialAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": ',
                    license.commercialRevShare.toString(),
                    "},",
                    '{"trait_type": "Commercial Revenue Celling", "value": ',
                    license.commercialRevCelling.toString(),
                    "},",
                    '{"trait_type": "Commercializer Check", "value": "',
                    license.commercializerChecker.toHexString(),
                    // Skip on commercializerCheckerData as it's bytes as irrelevant for the user metadata
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Encodes the derivative traits of PIL policy into a JSON string for OpenSea
    /// @param policy The policy to encode
    function _policyDerivativeTraitsToJson(License memory license) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RNFT_SUPPLY = 1000 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Derivatives Allowed", "value": "',
                    license.derivativesAllowed ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Attribution", "value": "',
                    license.derivativesAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Revenue Celling", "value": ',
                    license.derivativeRevCelling.toString(),
                    "},",
                    '{"trait_type": "Derivatives Approval", "value": "',
                    license.derivativesApproval ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Reciprocal", "value": "',
                    license.derivativesReciprocal ? "true" : "false",
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    /// @param royaltyPolicy The address of the royalty policy
    // solhint-disable-next-line code-complexity
    function _verifyCommercialUse(License calldata license) internal view {
        if (!license.commercialUse) {
            if (license.commercialAttribution) {
                revert PILFrameworkErrors.PILicenseTemplate__CommercialDisabled_CantAddAttribution();
            }
            if (license.commercializerChecker != address(0)) {
                revert PILFrameworkErrors.PILicenseTemplate__CommercialDisabled_CantAddCommercializers();
            }
            if (license.commercialRevShare > 0) {
                revert PILFrameworkErrors.PILicenseTemplate__CommercialDisabled_CantAddRevShare();
            }
            if (royaltyPolicy != address(0)) {
                revert PILFrameworkErrors.PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy();
            }
        } else {
            if (royaltyPolicy == address(0)) {
                revert PILFrameworkErrors.PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired();
            }
            if (license.commercializerChecker != address(0)) {
                if (!license.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                    revert Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook(
                        license.commercializerChecker
                    );
                }
                IHookModule(license.commercializerChecker).validateConfig(license.commercializerCheckerData);
            }
        }
    }

    /// @notice Checks the configuration of derivative parameters and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyDerivatives(License calldata license) internal pure {
        if (!license.derivativesAllowed) {
            if (license.derivativesAttribution) {
                revert PILFrameworkErrors.PILicenseTemplate__DerivativesDisabled_CantAddAttribution();
            }
            if (license.derivativesApproval) {
                revert PILFrameworkErrors.PILicenseTemplate__DerivativesDisabled_CantAddApproval();
            }
            if (license.derivativesReciprocal) {
                revert PILFrameworkErrors.PILicenseTemplate__DerivativesDisabled_CantAddReciprocal();
            }
        }
    }
}
