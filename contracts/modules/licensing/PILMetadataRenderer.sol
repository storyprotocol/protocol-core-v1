// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";


// contracts
import { PILTerms } from "../../interfaces/modules/licensing/IPILicenseTemplate.sol";


/// @title PILicenseTemplate
contract PILMetadataRenderer {
    using Strings for *;

    /// @notice Converts the license terms to a JSON string which will be part of the metadata of license token.
    /// @dev Must return OpenSea standard compliant metadata.
    /// @param terms The PIL License Terms to convert to JSON.
    /// @return The JSON string of the license terms, follow the OpenSea metadata standard.
    function toJson(PILTerms memory terms) external view returns (string memory) {

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
                policyCommercialTraitsToJson(terms),
                policyDerivativeTraitsToJson(terms)
            )
        );

        // NOTE: (above) last trait added by LicenseTemplate should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of PIL policy into a JSON string for OpenSea
    function policyCommercialTraitsToJson(PILTerms memory terms) public pure returns (string memory) {
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
    function policyDerivativeTraitsToJson(PILTerms memory terms) public pure returns (string memory) {
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
}
