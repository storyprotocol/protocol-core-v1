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
// solhint-disable-next-line max-line-length
import { IPILPolicyFrameworkManager, PILPolicy, PILAggregator, RegisterPILPolicyParams } from "../../interfaces/modules/licensing/IPILPolicyFrameworkManager.sol";
import { BasePolicyFrameworkManager } from "../../modules/licensing/BasePolicyFrameworkManager.sol";
import { LicensorApprovalChecker } from "../../modules/licensing/parameter-helpers/LicensorApprovalChecker.sol";

/// @title PILPolicyFrameworkManager
/// @notice PIL Policy Framework Manager implements the PIL Policy Framework logic for encoding and decoding PIL
/// policies into the LicenseRegistry and verifying the licensing parameters for linking, minting, and transferring.
contract PILPolicyFrameworkManager is
    IPILPolicyFrameworkManager,
    BasePolicyFrameworkManager,
    LicensorApprovalChecker,
    ReentrancyGuardUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;

    /// @dev Hash of an empty string array
    bytes32 private constant _EMPTY_STRING_ARRAY_HASH =
        0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;

    /// Constructor
    /// @param accessController the address of the AccessController
    /// @param ipAccountRegistry the address of the IPAccountRegistry
    /// @param licensing the address of the LicensingModule
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address licensing
    )
        BasePolicyFrameworkManager(licensing)
        LicensorApprovalChecker(
            accessController,
            ipAccountRegistry,
            address(ILicensingModule(licensing).LICENSE_REGISTRY())
        )
    {
        _disableInitializers();
    }

    function initialize(string memory name, string memory licenseTextUrl) external initializer {
        __BasePolicyFrameworkManager_init(name, licenseTextUrl);
        __ReentrancyGuard_init();
    }

    /// @notice Registers a new policy to the registry
    /// @dev Internally, this function must generate a Licensing.Policy struct and call registerPolicy.
    /// @param params parameters needed to register a PILPolicy
    /// @return policyId The ID of the newly registered policy
    function registerPolicy(RegisterPILPolicyParams calldata params) external nonReentrant returns (uint256 policyId) {
        /// Minting fee amount & address checked in LicensingModule, no need to check here.
        /// We don't limit charging for minting to commercial use, you could sell a NC license in theory.
        _verifyComercialUse(params.policy, params.royaltyPolicy, params.mintingFee, params.mintingFeeToken);
        _verifyDerivatives(params.policy);
        /// TODO: DO NOT deploy on production networks without hashing string[] values instead of storing them

        Licensing.Policy memory pol = Licensing.Policy({
            isLicenseTransferable: params.transferable,
            policyFramework: address(this),
            frameworkData: abi.encode(params.policy),
            royaltyPolicy: params.royaltyPolicy,
            royaltyData: abi.encode(params.policy.commercialRevShare),
            mintingFee: params.mintingFee,
            mintingFeeToken: params.mintingFeeToken
        });
        // No need to emit here, as the LicensingModule will emit the event
        return LICENSING_MODULE.registerPolicy(pol);
    }

    /// @notice Verify policy parameters for linking a child IP to a parent IP (licensor) by burning a license NFT.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @param licenseId the license id to burn
    /// @param licensee the address that holds the license and is executing the linking
    /// @param ipId the IP id of the IP being linked
    /// @param parentIpId the IP id of the parent IP
    /// @param policyData the encoded framework policy data to verify
    /// @return verified True if the link is verified
    function verifyLink(
        uint256 licenseId,
        address licensee,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external override nonReentrant onlyLicensingModule returns (bool) {
        PILPolicy memory policy = abi.decode(policyData, (PILPolicy));

        // Trying to burn a license to create a derivative, when the license doesn't allow derivatives.
        if (!policy.derivativesAllowed) {
            return false;
        }

        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (policy.derivativesApproval && !isDerivativeApproved(licenseId, ipId)) {
            return false;
        }
        // Check if the commercializerChecker allows the link
        if (policy.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(policy.commercializerChecker).verify(licensee, policy.commercializerCheckerData)) {
                return false;
            }
        }
        return true;
    }

    /// @notice Verify policy parameters for minting a license.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @param licensee the address that holds the license and is executing the mint
    /// @param mintingFromADerivative true if the license is minting from a derivative IPA
    /// @param licensorIpId the IP id of the licensor
    /// @param receiver the address receiving the license
    /// @param mintAmount the amount of licenses to mint
    /// @param policyData the encoded framework policy data to verify
    /// @return verified True if the link is verified
    function verifyMint(
        address licensee,
        bool mintingFromADerivative,
        address licensorIpId,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external nonReentrant onlyLicensingModule returns (bool) {
        PILPolicy memory policy = abi.decode(policyData, (PILPolicy));
        // If the policy defines no reciprocal derivatives are allowed (no derivatives of derivatives),
        // and we are mintingFromADerivative we don't allow minting
        if (!policy.derivativesReciprocal && mintingFromADerivative) {
            return false;
        }

        if (policy.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(policy.commercializerChecker).verify(licensee, policy.commercializerCheckerData)) {
                return false;
            }
        }

        return true;
    }

    /// @notice Returns the aggregation data for inherited policies of an IP asset.
    /// @param ipId The ID of the IP asset to get the aggregator for
    /// @return rights The PILAggregator struct
    function getAggregator(address ipId) external view returns (PILAggregator memory rights) {
        bytes memory policyAggregatorData = LICENSING_MODULE.policyAggregatorData(address(this), ipId);
        if (policyAggregatorData.length == 0) {
            revert PILFrameworkErrors.PILPolicyFrameworkManager__RightsNotFound();
        }
        rights = abi.decode(policyAggregatorData, (PILAggregator));
    }

    /// @notice gets the PILPolicy for a given policy ID decoded from Licensing.Policy.frameworkData
    /// @dev Do not call this function from a smart contract, it is only for off-chain
    /// @param policyId The ID of the policy to get
    /// @return policy The PILPolicy struct
    function getPILPolicy(uint256 policyId) external view returns (PILPolicy memory policy) {
        Licensing.Policy memory pol = LICENSING_MODULE.policy(policyId);
        return abi.decode(pol.frameworkData, (PILPolicy));
    }

    /// @notice Verify compatibility of one or more policies when inheriting them from one or more parent IPs.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @dev The assumption in this method is that we can add parents later on, hence the need
    /// for an aggregator, if not we will do this when linking to parents directly with an
    /// array of policies.
    /// @param aggregator common state of the policies for the IP
    /// @param policyId the ID of the policy being inherited
    /// @param policy the policy to inherit
    /// @return changedAgg  true if the aggregator was changed
    /// @return newAggregator the new aggregator
    // solhint-disable-next-line code-complexity
    function processInheritedPolicies(
        bytes memory aggregator,
        uint256 policyId,
        bytes memory policy
    ) external view onlyLicensingModule returns (bool changedAgg, bytes memory newAggregator) {
        PILAggregator memory agg;
        PILPolicy memory newPolicy = abi.decode(policy, (PILPolicy));
        if (aggregator.length == 0) {
            // Initialize the aggregator
            agg = PILAggregator({
                commercial: newPolicy.commercialUse,
                derivativesReciprocal: newPolicy.derivativesReciprocal,
                lastPolicyId: policyId,
                territoriesAcc: keccak256(abi.encode(newPolicy.territories)),
                distributionChannelsAcc: keccak256(abi.encode(newPolicy.distributionChannels)),
                contentRestrictionsAcc: keccak256(abi.encode(newPolicy.contentRestrictions))
            });
            return (true, abi.encode(agg));
        } else {
            agg = abi.decode(aggregator, (PILAggregator));

            // Either all are reciprocal or none are
            if (agg.derivativesReciprocal != newPolicy.derivativesReciprocal) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__ReciprocalValueMismatch();
            } else if (agg.derivativesReciprocal && newPolicy.derivativesReciprocal) {
                // Ids are uniqued because we hash them to compare on creation in LicenseRegistry,
                // so we can compare the ids safely.
                if (agg.lastPolicyId != policyId) {
                    revert PILFrameworkErrors.PILPolicyFrameworkManager__ReciprocalButDifferentPolicyIds();
                }
            } else {
                // Both non reciprocal
                if (agg.commercial != newPolicy.commercialUse) {
                    revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialValueMismatch();
                }

                bytes32 newHash = _verifHashedParams(
                    agg.territoriesAcc,
                    keccak256(abi.encode(newPolicy.territories)),
                    _EMPTY_STRING_ARRAY_HASH
                );
                if (newHash != agg.territoriesAcc) {
                    agg.territoriesAcc = newHash;
                    changedAgg = true;
                }
                newHash = _verifHashedParams(
                    agg.distributionChannelsAcc,
                    keccak256(abi.encode(newPolicy.distributionChannels)),
                    _EMPTY_STRING_ARRAY_HASH
                );
                if (newHash != agg.distributionChannelsAcc) {
                    agg.distributionChannelsAcc = newHash;
                    changedAgg = true;
                }
                newHash = _verifHashedParams(
                    agg.contentRestrictionsAcc,
                    keccak256(abi.encode(newPolicy.contentRestrictions)),
                    _EMPTY_STRING_ARRAY_HASH
                );
                if (newHash != agg.contentRestrictionsAcc) {
                    agg.contentRestrictionsAcc = newHash;
                    changedAgg = true;
                }
            }
        }
        return (changedAgg, abi.encode(agg));
    }

    /// @notice Returns the stringified JSON policy data for the LicenseRegistry.uri(uint256) method.
    /// @dev Must return ERC1155 OpenSea standard compliant metadata.
    /// @param policyData The encoded licensing policy data to be decoded by the PFM
    /// @return jsonString The OpenSea-compliant metadata URI of the policy
    function policyToJson(bytes memory policyData) public pure returns (string memory) {
        PILPolicy memory policy = abi.decode(policyData, (PILPolicy));

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata.
        // **Attributions**
        string memory json = string(
            abi.encodePacked(
                '{"trait_type": "Attribution", "value": "',
                policy.attribution ? "true" : "false",
                '"},',
                // Skip transferable, it's already added in the common attributes by the LicenseRegistry.
                // Should be managed by the LicenseRegistry, not the PFM.
                _policyCommercialTraitsToJson(policy),
                _policyDerivativeTraitsToJson(policy)
            )
        );

        json = string(abi.encodePacked(json, '{"trait_type": "Territories", "value": ['));
        uint256 count = policy.territories.length;
        for (uint256 i = 0; i < count; ++i) {
            json = string(abi.encodePacked(json, '"', policy.territories[i], '"'));
            if (i != count - 1) {
                // skip comma for last element in the array
                json = string(abi.encodePacked(json, ","));
            }
        }
        json = string(abi.encodePacked(json, "]},")); // close the trait_type: "Territories" array

        json = string(abi.encodePacked(json, '{"trait_type": "Distribution Channels", "value": ['));
        count = policy.distributionChannels.length;
        for (uint256 i = 0; i < count; ++i) {
            json = string(abi.encodePacked(json, '"', policy.distributionChannels[i], '"'));
            if (i != count - 1) {
                // skip comma for last element in the array
                json = string(abi.encodePacked(json, ","));
            }
        }
        json = string(abi.encodePacked(json, "]},")); // close the trait_type: "Distribution Channels" array

        // NOTE: (above) last trait added by PFM should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of PIL policy into a JSON string for OpenSea
    /// @param policy The policy to encode
    function _policyCommercialTraitsToJson(PILPolicy memory policy) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RT_SUPPLY = 100*10**18 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Commercial Use", "value": "',
                    policy.commercialUse ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Attribution", "value": "',
                    policy.commercialAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": ',
                    policy.commercialRevShare.toString(),
                    "},",
                    '{"trait_type": "Commercializer Check", "value": "',
                    policy.commercializerChecker.toHexString(),
                    // Skip on commercializerCheckerData as it's bytes as irrelevant for the user metadata
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Encodes the derivative traits of PIL policy into a JSON string for OpenSea
    /// @param policy The policy to encode
    function _policyDerivativeTraitsToJson(PILPolicy memory policy) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RT_SUPPLY = 100*10**18 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Derivatives Allowed", "value": "',
                    policy.derivativesAllowed ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Attribution", "value": "',
                    policy.derivativesAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Approval", "value": "',
                    policy.derivativesApproval ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Reciprocal", "value": "',
                    policy.derivativesReciprocal ? "true" : "false",
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    /// @param royaltyPolicy The address of the royalty policy
    // solhint-disable-next-line code-complexity
    function _verifyComercialUse(
        PILPolicy calldata policy,
        address royaltyPolicy,
        uint256 mintingFee,
        address mintingFeeToken
    ) internal view {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddAttribution();
            }
            if (policy.commercializerChecker != address(0)) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers();
            }
            if (policy.commercialRevShare > 0) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddRevShare();
            }
            if (royaltyPolicy != address(0)) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy();
            }
            if (mintingFee > 0) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddMintingFee();
            }
            if (mintingFeeToken != address(0)) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddMintingFeeToken();
            }
        } else {
            if (royaltyPolicy == address(0)) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__CommercialEnabled_RoyaltyPolicyRequired();
            }
            if (policy.commercializerChecker != address(0)) {
                if (!policy.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                    revert Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook(
                        policy.commercializerChecker
                    );
                }
                IHookModule(policy.commercializerChecker).validateConfig(policy.commercializerCheckerData);
            }
        }
    }

    /// @notice Checks the configuration of derivative parameters and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyDerivatives(PILPolicy calldata policy) internal pure {
        if (!policy.derivativesAllowed) {
            if (policy.derivativesAttribution) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution();
            }
            if (policy.derivativesApproval) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__DerivativesDisabled_CantAddApproval();
            }
            if (policy.derivativesReciprocal) {
                revert PILFrameworkErrors.PILPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal();
            }
        }
    }

    /// @dev Verifies compatibility for params where the valid options are either permissive value, or equal params
    /// @param oldHash hash of the old param
    /// @param newHash hash of the new param
    /// @param permissive hash of the most permissive param
    /// @return result the hash that's different from the permissive hash
    function _verifHashedParams(
        bytes32 oldHash,
        bytes32 newHash,
        bytes32 permissive
    ) internal pure returns (bytes32 result) {
        if (oldHash == newHash) {
            return newHash;
        }
        if (oldHash != permissive && newHash != permissive) {
            revert PILFrameworkErrors.PILPolicyFrameworkManager__StringArrayMismatch();
        }
        if (oldHash != permissive) {
            return oldHash;
        }
        if (newHash != permissive) {
            return newHash;
        }
    }
}
