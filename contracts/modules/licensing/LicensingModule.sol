// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IPolicyFrameworkManager } from "../../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { IModule } from "../../interfaces/modules/base/IModule.sol";
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "../../lib/Errors.sol";
import { DataUniqueness } from "../../lib/DataUniqueness.sol";
import { Licensing } from "../../lib/Licensing.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { RoyaltyModule } from "../../modules/royalty/RoyaltyModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { LICENSING_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";
import { GovernableUpgradeable } from "../../governance/GovernableUpgradeable.sol";

// TODO: consider disabling operators/approvals on creation
/// @title Licensing Module
/// @notice Licensing module is the main entry point for the licensing system. It is responsible for:
/// - Registering policy frameworks
/// - Registering policies
/// - Minting licenses
/// - Linking IP to its parent
/// - Verifying linking parameters
/// - Verifying policy parameters
contract LicensingModule is
    AccessControlled,
    ILicensingModule,
    BaseModule,
    ReentrancyGuardUpgradeable,
    GovernableUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Licensing for *;
    using Strings for *;

    /// @notice Storage struct for the LicensingModule
    /// @param registeredFrameworkManagers Mapping of registered policy framework managers
    /// @param hashedPolicies Mapping of policy data to policy id
    /// @param policies Mapping of policy id to policy data (hashed)
    /// @param totalPolicies Total amount of distinct licensing policies in LicenseRegistry
    /// @param policySetups Internal mapping to track if a policy was set by linking or minting,
    /// and the index of the policy in the
    /// ipId policy set. Policies can't be removed, but they can be deactivated by setting active to false.
    /// @param policiesPerIpId the set of policy ids attached to the given ipId
    /// @param ipIdParents Mapping of parent policy ids for the given ipId
    /// @param ipRights Mapping of policy aggregator data for the given ipId in a framework
    /// @custom:storage-location erc7201:story-protocol.LicensingModule
    struct LicensingModuleStorage {
        mapping(address framework => bool registered) registeredFrameworkManagers;
        mapping(bytes32 policyHash => uint256 policyId) hashedPolicies;
        mapping(uint256 policyId => Licensing.Policy policyData) policies;
        uint256 totalPolicies;
        mapping(address ipId => mapping(uint256 policyId => PolicySetup setup)) policySetups;
        mapping(bytes32 hashIpIdAnInherited => EnumerableSet.UintSet policyIds) policiesPerIpId;
        mapping(address ipId => EnumerableSet.AddressSet parentIpIds) ipIdParents;
        mapping(address framework => mapping(address ipId => bytes policyAggregatorData)) ipRights;
    }

    /// @inheritdoc IModule
    string public constant override name = LICENSING_MODULE_KEY;

    /// @notice Returns the canonical protocol-wide RoyaltyModule
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    RoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicensingModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicensingModuleStorageLocation =
        0x0f7178cb62e4803c52d40f70c08a6f88d6ee1af1838d58e0c83a222a6c3d3100;

    /// @notice Modifier to allow only LicenseRegistry as the caller
    modifier onlyLicenseRegistry() {
        if (msg.sender == address(LICENSE_REGISTRY)) revert Errors.LicensingModule__CallerNotLicenseRegistry();
        _;
    }

    /// Constructor
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @param royaltyModule The address of the RoyaltyModule contract
    /// @param registry The address of the LicenseRegistry contract
    /// @param disputeModule The address of the DisputeModule contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address royaltyModule,
        address registry,
        address disputeModule
    ) AccessControlled(accessController, ipAccountRegistry) {
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
        LICENSE_REGISTRY = ILicenseRegistry(registry);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param governance The address of the governance contract
    function initialize(address governance) public initializer {
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __GovernableUpgradeable_init(governance);
    }

    /// @notice Registers a policy framework manager into the contract, so it can add policy data for licenses.
    /// @param manager the address of the manager. Will be ERC165 checked for IPolicyFrameworkManager
    function registerPolicyFrameworkManager(address manager) external {
        if (!ERC165Checker.supportsInterface(manager, type(IPolicyFrameworkManager).interfaceId)) {
            revert Errors.LicensingModule__InvalidPolicyFramework();
        }
        IPolicyFrameworkManager fwManager = IPolicyFrameworkManager(manager);
        string memory licenseUrl = fwManager.licenseTextUrl();
        if (bytes(licenseUrl).length == 0 || licenseUrl.equal("")) {
            revert Errors.LicensingModule__EmptyLicenseUrl();
        }
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        $.registeredFrameworkManagers[manager] = true;

        emit PolicyFrameworkRegistered(manager, fwManager.name(), licenseUrl);
    }

    /// @notice Registers a policy into the contract. MUST be called by a registered framework or it will revert.
    /// The policy data and its integrity must be verified by the policy framework manager.
    /// @param pol The Licensing policy data. MUST have same policy framework as the caller address
    /// @return policyId The id of the newly registered policy
    function registerPolicy(Licensing.Policy memory pol) external returns (uint256 policyId) {
        _verifyRegisteredFramework(address(msg.sender));
        if (pol.policyFramework != address(msg.sender)) {
            revert Errors.LicensingModule__RegisterPolicyFrameworkMismatch();
        }
        if (pol.royaltyPolicy != address(0) && !ROYALTY_MODULE.isWhitelistedRoyaltyPolicy(pol.royaltyPolicy)) {
            revert Errors.LicensingModule__RoyaltyPolicyNotWhitelisted();
        }
        if (pol.mintingFee > 0 && !ROYALTY_MODULE.isWhitelistedRoyaltyToken(pol.mintingFeeToken)) {
            revert Errors.LicensingModule__MintingFeeTokenNotWhitelisted();
        }
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        (uint256 polId, bool newPol) = DataUniqueness.addIdOrGetExisting(
            abi.encode(pol),
            $.hashedPolicies,
            $.totalPolicies
        );
        if (newPol) {
            $.totalPolicies = polId;
            $.policies[polId] = pol;
            emit PolicyRegistered(
                polId,
                pol.policyFramework,
                pol.frameworkData,
                pol.royaltyPolicy,
                pol.royaltyData,
                pol.mintingFee,
                pol.mintingFeeToken
            );
        }
        return polId;
    }

    /// @notice Adds a policy to the set of policies of an IP. Reverts if policy is undefined in LicenseRegistry.
    /// @param ipId The id of the IP
    /// @param polId The id of the policy
    /// @return indexOnIpId The index of the policy in the IP's policy list
    function addPolicyToIp(
        address ipId,
        uint256 polId
    ) external nonReentrant verifyPermission(ipId) returns (uint256 indexOnIpId) {
        if (!isPolicyDefined(polId)) {
            revert Errors.LicensingModule__PolicyNotFound();
        }
        _verifyIpNotDisputed(ipId);

        return _addPolicyIdToIp({ ipId: ipId, policyId: polId, isInherited: false, skipIfDuplicate: false });
    }

    /// @notice Mints a license to create derivative IP. License NFTs represent a policy granted by IPs (licensors).
    /// Reverts if caller is not authorized by any of the licensors.
    /// @dev This NFT needs to be burned in order to link a derivative IP with its parents. If this is the first
    /// combination of policy and licensors, a new licenseId will be created (by incrementing prev totalLicenses).
    /// If not, the license is fungible and an id will be reused. The licensing terms that regulate creating new
    /// licenses will be verified to allow minting.
    /// @param policyId The id of the policy with the licensing parameters
    /// @param licensorIpId The id of the licensor IP
    /// @param amount The amount of licenses to mint
    /// @param receiver The address that will receive the license
    /// @param royaltyContext The context for the royalty module to process
    /// @return licenseId The ID of the license NFT(s)
    // solhint-disable-next-line code-complexity
    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        uint256 amount, // mint amount
        address receiver,
        bytes calldata royaltyContext
    ) external nonReentrant returns (uint256 licenseId) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        _verifyPolicy($.policies[policyId]);
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(licensorIpId)) {
            revert Errors.LicensingModule__LicensorNotRegistered();
        }
        if (amount == 0) {
            revert Errors.LicensingModule__MintAmountZero();
        }
        if (receiver == address(0)) {
            revert Errors.LicensingModule__ReceiverZeroAddress();
        }
        _verifyIpNotDisputed(licensorIpId);

        bool isInherited = $.policySetups[licensorIpId][policyId].isInherited;
        Licensing.Policy memory pol = policy(policyId);

        IPolicyFrameworkManager pfm = IPolicyFrameworkManager(pol.policyFramework);

        // If the IP ID doesn't have a policy (meaning, no derivatives), this means the caller is attempting to mint a
        // license on a private policy. IP account can mint license NFTs on a globally registerd policy (via PFM)
        // without attaching the policy to the IP account, thus making it a private policy licenses.
        if (!_policySetPerIpId(isInherited, licensorIpId).contains(policyId)) {
            // We have to check if the caller is licensor or authorized to mint.
            if (!_hasPermission(licensorIpId)) {
                revert Errors.LicensingModule__CallerNotLicensorAndPolicyNotSet();
            }
        }

        // If the policy has a royalty policy, we need to call the royalty module to process the minting.
        // Otherwise, it's non commercial and we can skip the call.
        // NOTE: We must call `payLicenseMintingFee` after calling `onLicenseMinting` because minting licenses on
        // root IPs (licensors) might mean the licensors don't have royalty policy initialized, so we initialize it
        // (deploy the split clone contract) via `onLicenseMinting`. Then, pay the minting fee to the licensor's split
        // clone contract address.
        if (pol.royaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLicenseMinting(licensorIpId, pol.royaltyPolicy, pol.royaltyData, royaltyContext);

            // If there's a minting fee, sender must pay it
            if (pol.mintingFee > 0) {
                ROYALTY_MODULE.payLicenseMintingFee(
                    licensorIpId,
                    msg.sender,
                    pol.royaltyPolicy,
                    pol.mintingFeeToken,
                    pol.mintingFee * amount
                );
            }
        }

        // If a policy is set, then is only up to the policy params.
        // When verifying mint via PFM, pass in `receiver` as the `licensee` since the receiver is the one who will own
        // the license NFT after minting.
        if (!pfm.verifyMint(receiver, isInherited, licensorIpId, receiver, amount, pol.frameworkData)) {
            revert Errors.LicensingModule__MintLicenseParamFailed();
        }

        licenseId = LICENSE_REGISTRY.mintLicense(policyId, licensorIpId, pol.isLicenseTransferable, amount, receiver);
    }

    /// @notice Links an IP to the licensors listed in the license NFTs, if their policies allow it. Burns the license
    /// NFTs in the proccess. The caller must be the owner of the IP asset and license NFTs.
    /// @param licenseIds The id of the licenses to burn
    /// @param childIpId The id of the child IP to be linked
    /// @param royaltyContext The context for the royalty module to process
    function linkIpToParents(
        uint256[] calldata licenseIds,
        address childIpId,
        bytes calldata royaltyContext
    ) external nonReentrant verifyPermission(childIpId) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        if ($.ipIdParents[childIpId].length() > 0) {
            revert Errors.LicensingModule__IpAlreadyLinked();
        }

        _verifyIpNotDisputed(childIpId);
        address holder = IIPAccount(payable(childIpId)).owner();
        address[] memory licensors = new address[](licenseIds.length);
        bytes[] memory royaltyData = new bytes[](licenseIds.length);
        // If royalty policy address is address(0), this means no royalty policy to set.
        address royaltyAddressAcc = address(0);

        for (uint256 i = 0; i < licenseIds.length; i++) {
            if (LICENSE_REGISTRY.isLicenseRevoked(licenseIds[i])) {
                revert Errors.LicensingModule__LinkingRevokedLicense();
            }
            // This function:
            // - Verifies the license holder is the caller
            // - Verifies the license is valid (through IPolicyFrameworkManager)
            // - Verifies all licenses must have either no royalty policy or the same one.
            //   (That's why we send the royaltyAddressAcc and get it as a return value).
            // Finally, it will add the policy to the child IP, and set the parent.
            (licensors[i], royaltyAddressAcc, royaltyData[i]) = _verifyRoyaltyAndLink(
                i,
                licenseIds[i],
                childIpId,
                holder,
                royaltyAddressAcc
            );
        }
        emit IpIdLinkedToParents(msg.sender, childIpId, licensors);

        // Licenses unanimously require royalty, so we can call the royalty module
        if (royaltyAddressAcc != address(0)) {
            ROYALTY_MODULE.onLinkToParents(childIpId, royaltyAddressAcc, licensors, royaltyData, royaltyContext);
        }

        // Burn licenses
        LICENSE_REGISTRY.burnLicenses(holder, licenseIds);
    }

    /// @dev Verifies royalty and link params, and returns the licensor, new royalty policy and royalty data
    /// This function was added to avoid stack too deep error.
    function _verifyRoyaltyAndLink(
        uint256 i,
        uint256 licenseId,
        address childIpId,
        address holder,
        address royaltyAddressAcc
    ) private returns (address licensor, address newRoyaltyAcc, bytes memory royaltyData) {
        if (!LICENSE_REGISTRY.isLicensee(licenseId, holder)) {
            revert Errors.LicensingModule__NotLicensee();
        }
        Licensing.License memory licenseData = LICENSE_REGISTRY.license(licenseId);
        Licensing.Policy memory pol = policy(licenseData.policyId);
        // Check if all licenses have the same policy.
        if (i > 0 && pol.royaltyPolicy != royaltyAddressAcc) {
            revert Errors.LicensingModule__IncompatibleLicensorCommercialPolicy();
        }

        _linkIpToParent(i, licenseId, licenseData.policyId, pol, licenseData.licensorIpId, childIpId, holder);
        return (licenseData.licensorIpId, pol.royaltyPolicy, pol.royaltyData);
    }

    /// @notice Returns if the framework address is registered in the LicensingModule.
    /// @param policyFramework The address of the policy framework manager
    /// @return isRegistered True if the framework is registered
    function isFrameworkRegistered(address policyFramework) external view returns (bool) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.registeredFrameworkManagers[policyFramework];
    }

    /// @notice Returns amount of distinct licensing policies in the LicensingModule.
    /// @return totalPolicies The amount of policies
    function totalPolicies() external view returns (uint256) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.totalPolicies;
    }

    /// @notice Returns the policy data for policyId, reverts if not found.
    /// @param policyId The id of the policy
    /// @return pol The policy data
    function policy(uint256 policyId) public view returns (Licensing.Policy memory pol) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        pol = $.policies[policyId];
        _verifyPolicy(pol);
        return pol;
    }

    /// @notice Returns the policy id for the given policy data, or 0 if not found.
    /// @param pol The policy data in Policy struct
    /// @return policyId The id of the policy
    function getPolicyId(Licensing.Policy calldata pol) external view returns (uint256 policyId) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.hashedPolicies[keccak256(abi.encode(pol))];
    }

    /// @notice Returns the policy aggregator data for the given IP ID in the framework.
    /// @param framework The address of the policy framework manager
    /// @param ipId The id of the IP asset
    /// @return data The encoded policy aggregator data to be decoded by the framework manager
    function policyAggregatorData(address framework, address ipId) external view returns (bytes memory) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.ipRights[framework][ipId];
    }

    /// @notice Returns if policyId exists in the LicensingModule
    /// @param policyId The id of the policy
    /// @return isDefined True if the policy is defined
    function isPolicyDefined(uint256 policyId) public view returns (bool) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.policies[policyId].policyFramework != address(0);
    }

    /// @notice Returns the policy ids attached to an IP
    /// @dev Potentially gas-intensive operation, use with care.
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @return policyIds The ids of policy ids for the IP
    function policyIdsForIp(bool isInherited, address ipId) external view returns (uint256[] memory policyIds) {
        return _policySetPerIpId(isInherited, ipId).values();
    }

    /// @notice Returns the total number of policies attached to an IP
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @return totalPolicies The total number of policies for the IP
    function totalPoliciesForIp(bool isInherited, address ipId) public view returns (uint256) {
        return _policySetPerIpId(isInherited, ipId).length();
    }

    /// @notice True if the given policy attached to the given IP is inherited from a parent IP.
    /// @param ipId The id of the IP asset that has the policy attached
    /// @param policyId The id of the policy to check if inherited
    /// @return isInherited True if the policy is inherited from a parent IP
    function isPolicyIdSetForIp(bool isInherited, address ipId, uint256 policyId) external view returns (bool) {
        return _policySetPerIpId(isInherited, ipId).contains(policyId);
    }

    /// @notice Returns the policy ID for an IP by local index on the IP's policy set
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset to check
    /// @param index The local index of a policy in the IP's policy set
    /// @return policyId The id of the policy
    function policyIdForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (uint256 policyId) {
        return _policySetPerIpId(isInherited, ipId).at(index);
    }

    /// @notice Returns the policy data for an IP by the policy's local index on the IP's policy set
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset to check
    /// @param index The local index of a policy in the IP's policy set
    /// @return policy The policy data
    function policyForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (Licensing.Policy memory) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.policies[_policySetPerIpId(isInherited, ipId).at(index)];
    }

    /// @notice Returns the status of a policy in an IP's policy set
    /// @param ipId The id of the IP asset to check
    /// @param policyId The id of the policy
    /// @return index The local index of the policy in the IP's policy set
    /// @return isInherited True if the policy is inherited from a parent IP
    /// @return active True if the policy is active
    function policyStatus(
        address ipId,
        uint256 policyId
    ) external view returns (uint256 index, bool isInherited, bool active) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        PolicySetup storage setup = $.policySetups[ipId][policyId];
        return (setup.index, setup.isInherited, setup.active);
    }

    /// @notice Returns if the given policy attached to the given IP is inherited from a parent IP.
    /// @param ipId The id of the IP asset that has the policy attached
    /// @param policyId The id of the policy to check if inherited
    /// @return isInherited True if the policy is inherited from a parent IP
    function isPolicyInherited(address ipId, uint256 policyId) external view returns (bool) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.policySetups[ipId][policyId].isInherited;
    }

    /// @notice Returns if an IP is a derivative of another IP
    /// @param parentIpId The id of the parent IP asset to check
    /// @param childIpId The id of the child IP asset to check
    /// @return isParent True if the child IP is a derivative of the parent IP
    function isParent(address parentIpId, address childIpId) external view returns (bool) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.ipIdParents[childIpId].contains(parentIpId);
    }

    /// @notice Returns the list of parent IP assets for a given child IP asset
    /// @param ipId The id of the child IP asset to check
    /// @return parentIpIds The ids of the parent IP assets
    function parentIpIds(address ipId) external view returns (address[] memory) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.ipIdParents[ipId].values();
    }

    /// @notice Returns the total number of parents for an IP asset
    /// @param ipId The id of the IP asset to check
    /// @return totalParents The total number of parent IP assets
    function totalParentsForIpId(address ipId) external view returns (uint256) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.ipIdParents[ipId].length();
    }

    /// @dev Verifies that the framework is registered in the LicensingModule
    function _verifyRegisteredFramework(address policyFramework) private view {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        if (!$.registeredFrameworkManagers[policyFramework]) {
            revert Errors.LicensingModule__FrameworkNotFound();
        }
    }

    /// @dev Adds a policy id to the ipId policy set. Reverts if policy set already has policyId
    function _addPolicyIdToIp(
        address ipId,
        uint256 policyId,
        bool isInherited,
        bool skipIfDuplicate
    ) private returns (uint256 index) {
        _verifyCanAddPolicy(policyId, ipId, isInherited);
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        // Try and add the policy into the set.
        EnumerableSet.UintSet storage _pols = _policySetPerIpId(isInherited, ipId);
        if (!_pols.add(policyId)) {
            if (skipIfDuplicate) {
                return $.policySetups[ipId][policyId].index;
            }
            revert Errors.LicensingModule__PolicyAlreadySetForIpId();
        }
        index = _pols.length() - 1;
        PolicySetup storage setup = $.policySetups[ipId][policyId];
        // This should not happen, but just in case
        if (setup.isSet) {
            revert Errors.LicensingModule__PolicyAlreadySetForIpId();
        }
        setup.index = index;
        setup.isSet = true;
        setup.active = true;
        setup.isInherited = isInherited;
        emit PolicyAddedToIpId(msg.sender, ipId, policyId, index, isInherited);
        return index;
    }

    /// @dev Link IP to a parent IP using the license NFT.
    function _linkIpToParent(
        uint256 iteration,
        uint256 licenseId,
        uint256 policyId,
        Licensing.Policy memory pol,
        address licensor,
        address childIpId,
        address licensee
    ) private {
        // TODO: check licensor not part of a branch tagged by disputer
        if (licensor == childIpId) {
            revert Errors.LicensingModule__ParentIdEqualThanChild();
        }
        // Verify linking params
        if (
            !IPolicyFrameworkManager(pol.policyFramework).verifyLink(
                licenseId,
                licensee,
                childIpId,
                licensor,
                pol.frameworkData
            )
        ) {
            revert Errors.LicensingModule__LinkParentParamFailed();
        }

        // Add the policy of licenseIds[i] to the child. If the policy's already set from previous parents,
        // then the addition will be skipped.
        _addPolicyIdToIp({ ipId: childIpId, policyId: policyId, isInherited: true, skipIfDuplicate: true });
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        // Set parent. We ignore the return value, since there are some cases where the same licensor gives the child
        // a License with another policy.
        $.ipIdParents[childIpId].add(licensor);
    }

    /// @dev Verifies if the policyId can be added to the IP
    function _verifyCanAddPolicy(uint256 policyId, address ipId, bool isInherited) private {
        bool ipIdIsDerivative = _policySetPerIpId(true, ipId).length() > 0;
        if (
            // Original work, owner is setting policies
            // (ipIdIsDerivative false, adding isInherited false)
            (!ipIdIsDerivative && !isInherited)
        ) {
            // Can add policy
            return;
        } else if (ipIdIsDerivative && !isInherited) {
            // Owner of derivative is trying to set policies
            revert Errors.LicensingModule__DerivativesCannotAddPolicy();
        }
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        // If we are here, this is a multiparent derivative
        // Checking for policy compatibility
        IPolicyFrameworkManager polManager = IPolicyFrameworkManager(policy(policyId).policyFramework);
        Licensing.Policy memory pol = $.policies[policyId];
        (bool aggregatorChanged, bytes memory newAggregator) = polManager.processInheritedPolicies(
            $.ipRights[pol.policyFramework][ipId],
            policyId,
            pol.frameworkData
        );
        if (aggregatorChanged) {
            $.ipRights[pol.policyFramework][ipId] = newAggregator;
        }
    }

    /// @dev Verifies if the policy is set
    function _verifyPolicy(Licensing.Policy memory pol) private pure {
        if (pol.policyFramework == address(0)) {
            revert Errors.LicensingModule__PolicyNotFound();
        }
    }

    /// @dev Returns the policy set for the given ipId
    function _policySetPerIpId(bool isInherited, address ipId) private view returns (EnumerableSet.UintSet storage) {
        LicensingModuleStorage storage $ = _getLicensingModuleStorage();
        return $.policiesPerIpId[keccak256(abi.encode(isInherited, ipId))];
    }

    /// @dev Verifies if the IP is disputed
    function _verifyIpNotDisputed(address ipId) private view {
        // TODO: in beta, any tag means revocation, for mainnet we need more context
        if (DISPUTE_MODULE.isIpTagged(ipId)) {
            revert Errors.LicensingModule__DisputedIpId();
        }
    }

    /// @dev Returns the storage struct of LicensingModule.
    function _getLicensingModuleStorage() private pure returns (LicensingModuleStorage storage $) {
        assembly {
            $.slot := LicensingModuleStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyProtocolAdmin {}
}
