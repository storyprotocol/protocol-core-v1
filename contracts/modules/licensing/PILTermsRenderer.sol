// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { PILTerms } from "../../interfaces/modules/licensing/IPILicenseTemplate.sol";

/// @title PILicenseTemplate
contract PILTermsRenderer {
    using Strings for *;

    /// @notice Encodes the PIL terms into a JSON string on the OpenSea standard
    /// @param terms The PIL terms to encode
    /// @return The JSON string
    function termsToJson(PILTerms memory terms) external pure returns (string memory) {
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
                '{"trait_type": "URI", "value": "',
                terms.uri,
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
                    '{"trait_type": "Commercial Revenue Ceiling", "value": ',
                    terms.commercialRevCeiling.toString(),
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
                    '{"trait_type": "Derivatives Revenue Ceiling", "value": ',
                    terms.derivativeRevCeiling.toString(),
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
}
