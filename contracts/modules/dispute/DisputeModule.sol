// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";

import { DISPUTE_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../../modules/BaseModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { IGroupIPAssetRegistry } from "../../interfaces/registries/IGroupIPAssetRegistry.sol";
import { Errors } from "../../lib/Errors.sol";
import { ProtocolPausableUpgradeable } from "../../pause/ProtocolPausableUpgradeable.sol";
import { IPGraphACL } from "../../access/IPGraphACL.sol";

/// @title Dispute Module
/// @notice The dispute module acts as an enforcement layer for IP assets that allows raising and resolving disputes
/// through arbitration by judges.
contract DisputeModule is
    IDisputeModule,
    BaseModule,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlled,
    UUPSUpgradeable,
    MulticallUpgradeable
{
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev Storage for DisputeModule
    /// @param disputeCounter The dispute ID counter
    /// @param arbitrationPolicyCooldown The cooldown for updating the arbitration policy
    /// @param baseArbitrationPolicy The address of the base arbitration policy
    /// @param disputes Returns the dispute information for a given dispute id
    /// @param isWhitelistedDisputeTag Indicates if a dispute tag is whitelisted
    /// @param isWhitelistedArbitrationPolicy Indicates if an arbitration policy is whitelisted
    /// @param arbitrationRelayer The arbitration relayer address for a given arbitration policy
    /// @param arbitrationPolicies Arbitration policy for a given ipId
    /// @param nextArbitrationPolicies Next arbitration policy for a given ipId
    /// @param arbitrationUpdateTimestamps Timestamp of when the arbitration policy will be updated for a given ipId
    /// @param successfulDisputesPerIp Counter of successful disputes per ipId
    /// @param isDisputePropagated Indicates if a dispute has been propagated from a parent ipId to a derivative ipId
    /// @custom:storage-location erc7201:story-protocol.DisputeModule
    struct DisputeModuleStorage {
        uint256 disputeCounter;
        uint256 arbitrationPolicyCooldown;
        address baseArbitrationPolicy;
        mapping(uint256 disputeId => Dispute) disputes;
        mapping(bytes32 tag => bool) isWhitelistedDisputeTag;
        mapping(address arbitrationPolicy => bool) isWhitelistedArbitrationPolicy;
        mapping(address arbitrationPolicy => address relayer) arbitrationRelayer;
        mapping(address ipId => address) arbitrationPolicies;
        mapping(address ipId => address) nextArbitrationPolicies;
        mapping(address ipId => uint256) nextArbitrationUpdateTimestamps;
        mapping(address ipId => uint256) successfulDisputesPerIp;
        mapping(address ipId => mapping(uint256 disputeId => bool)) isDisputePropagated;
        mapping(bytes32 evidenceHash => bool) isUsedEvidenceHash;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.DisputeModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DisputeModuleStorageLocation =
        0x682945c2d364b4630e68ffe0854d372acb0c4ff549a1e3dbc6f878bd8da0c800;

    string public constant override name = DISPUTE_MODULE_KEY;

    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    /// @notice Protocol-wide license registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Protocol-wide group IP asset registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable GROUP_IP_ASSET_REGISTRY;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IPGraphACL public immutable IP_GRAPH_ACL;

    /// Constructor
    /// @param accessController The address of the access controller
    /// @param ipAssetRegistry The address of the asset registry
    /// @param licenseRegistry The address of the license registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry,
        address ipGraphAcl
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (licenseRegistry == address(0)) revert Errors.DisputeModule__ZeroLicenseRegistry();
        if (ipAssetRegistry == address(0)) revert Errors.DisputeModule__ZeroIPAssetRegistry();
        if (accessController == address(0)) revert Errors.DisputeModule__ZeroAccessController();
        if (ipGraphAcl == address(0)) revert Errors.DisputeModule__ZeroIPGraphACL();

        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        GROUP_IP_ASSET_REGISTRY = IGroupIPAssetRegistry(ipAssetRegistry);
        IP_GRAPH_ACL = IPGraphACL(ipGraphAcl);
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) {
            revert Errors.DisputeModule__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Multicall_init();
    }

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external restricted {
        if (tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();
        if (tag == IN_DISPUTE) revert Errors.DisputeModule__NotAllowedToWhitelist();

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.isWhitelistedDisputeTag[tag] = allowed;

        emit TagWhitelistUpdated(tag, allowed);
    }

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external restricted {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (arbitrationPolicy == $.baseArbitrationPolicy && !allowed)
            revert Errors.DisputeModule__CannotBlacklistBaseArbitrationPolicy();

        $.isWhitelistedArbitrationPolicy[arbitrationPolicy] = allowed;

        emit ArbitrationPolicyWhitelistUpdated(arbitrationPolicy, allowed);
    }

    /// @notice Sets the arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    function setArbitrationRelayer(address arbitrationPolicy, address arbPolicyRelayer) external restricted {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.arbitrationRelayer[arbitrationPolicy] = arbPolicyRelayer;

        emit ArbitrationRelayerUpdated(arbitrationPolicy, arbPolicyRelayer);
    }

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external restricted {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        $.baseArbitrationPolicy = arbitrationPolicy;

        emit DefaultArbitrationPolicyUpdated(arbitrationPolicy);
    }

    /// @notice Sets the arbitration policy cooldown
    /// @param cooldown The cooldown in seconds
    function setArbitrationPolicyCooldown(uint256 cooldown) external restricted {
        if (cooldown == 0) revert Errors.DisputeModule__ZeroArbitrationPolicyCooldown();
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.arbitrationPolicyCooldown = cooldown;

        emit ArbitrationPolicyCooldownUpdated(cooldown);
    }

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param nextArbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(
        address ipId,
        address nextArbitrationPolicy
    ) external whenNotPaused verifyPermission(ipId) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedArbitrationPolicy[nextArbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        // if applicable updates the active arbitration policy to the queued arbitration policy
        // before setting the new next arbitration policy
        _updateActiveArbitrationPolicy(ipId);

        $.nextArbitrationPolicies[ipId] = nextArbitrationPolicy;

        uint256 nextArbitrationUpdateTimestamp = block.timestamp + $.arbitrationPolicyCooldown;
        $.nextArbitrationUpdateTimestamps[ipId] = nextArbitrationUpdateTimestamp;

        emit ArbitrationPolicySet(ipId, nextArbitrationPolicy, nextArbitrationUpdateTimestamp);
    }

    /// @notice Raises a dispute on a given ipId
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The id of the newly raised dispute
    function raiseDispute(
        address targetIpId,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        bytes calldata data
    ) external nonReentrant whenNotPaused returns (uint256) {
        return _raiseDispute(targetIpId, msg.sender, disputeEvidenceHash, targetTag, data);
    }

    /// @notice Raises a dispute on a given ipId on behalf of a given address
    /// The dispute initiator address will receive the bond winnings in case of winning the dispute
    /// and also has the right to resolve the dispute
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The id of the newly raised dispute
    function raiseDisputeOnBehalf(
        address targetIpId,
        address disputeInitiator,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        bytes calldata data
    ) external nonReentrant whenNotPaused returns (uint256) {
        return _raiseDispute(targetIpId, disputeInitiator, disputeEvidenceHash, targetTag, data);
    }

    /// @notice Sets the dispute judgement on a given dispute. Only whitelisted arbitration relayers can call to judge.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(
        uint256 disputeId,
        bool decision,
        bytes calldata data
    ) external nonReentrant whenNotPaused {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();

        Dispute memory dispute = $.disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if ($.arbitrationRelayer[dispute.arbitrationPolicy] != msg.sender)
            revert Errors.DisputeModule__NotArbitrationRelayer();

        if (decision) {
            $.disputes[disputeId].currentTag = dispute.targetTag;
            $.successfulDisputesPerIp[dispute.targetIpId]++;
        } else {
            $.disputes[disputeId].currentTag = bytes32(0);
        }

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeJudgement(disputeId, decision, data);

        emit DisputeJudgementSet(disputeId, decision, data);
    }

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external nonReentrant whenNotPaused {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        Dispute memory dispute = $.disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, disputeId, data);

        $.disputes[disputeId].currentTag = bytes32(0);

        emit DisputeCancelled(disputeId, data);
    }

    /// @notice Tags a derivative if a parent has been tagged with an infringement tag
    /// or a group ip if a group member has been tagged with an infringement tag
    /// @param ipIdToTag The ipId to tag
    /// @param infringerDisputeId The dispute id that tagged the related infringing ipId
    function tagIfRelatedIpInfringed(address ipIdToTag, uint256 infringerDisputeId) external whenNotPaused {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();

        Dispute memory infringerDispute = $.disputes[infringerDisputeId];
        address infringerIpId = infringerDispute.targetIpId;

        // a dispute current tag can be in 3 states:
        // IN_DISPUTE, 0, or a tag (ie. "IMPROPER_REGISTRATION")
        // by restricting IN_DISPUTE and 0 - it is ensured the infringer has been tagged before tagging the ipIdToTag
        if (infringerDispute.currentTag == IN_DISPUTE || infringerDispute.currentTag == bytes32(0))
            revert Errors.DisputeModule__DisputeWithoutInfringementTag();

        // if the ipIdToTag is a group ip, check if the infringer is a member of the group
        // if the ipIdToTag is not a group ip, check if the infringer is the parent ipId
        IP_GRAPH_ACL.startInternalAccess();
        if (
            !LICENSE_REGISTRY.isParentIp(infringerIpId, ipIdToTag) &&
            !GROUP_IP_ASSET_REGISTRY.containsIp(ipIdToTag, infringerIpId)
        ) revert Errors.DisputeModule__NotDerivativeOrGroupIp();
        IP_GRAPH_ACL.endInternalAccess();

        if ($.isDisputePropagated[ipIdToTag][infringerDisputeId])
            revert Errors.DisputeModule__DisputeAlreadyPropagated();

        uint256 disputeId = ++$.disputeCounter;
        uint256 disputeTimestamp = block.timestamp;

        $.disputes[disputeId] = Dispute({
            targetIpId: ipIdToTag,
            disputeInitiator: msg.sender,
            disputeTimestamp: disputeTimestamp,
            arbitrationPolicy: infringerDispute.arbitrationPolicy,
            disputeEvidenceHash: infringerDispute.disputeEvidenceHash,
            targetTag: infringerDispute.currentTag,
            currentTag: infringerDispute.currentTag,
            infringerDisputeId: infringerDisputeId
        });

        $.isDisputePropagated[ipIdToTag][infringerDisputeId] = true;
        $.successfulDisputesPerIp[ipIdToTag]++;

        emit IpTaggedOnRelatedIpInfringement(
            disputeId,
            infringerIpId,
            ipIdToTag,
            infringerDisputeId,
            infringerDispute.currentTag,
            disputeTimestamp
        );
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute id
    /// @param data The data to resolve the dispute
    function resolveDispute(uint256 disputeId, bytes calldata data) external nonReentrant whenNotPaused {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        Dispute memory dispute = $.disputes[disputeId];

        // there are two types of disputes - those that are subject to judgment and those that are not
        // the way to distinguish is by whether dispute.infringerDisputeId is 0 or higher than 0
        // for the former - only the dispute initiator can resolve
        if (dispute.infringerDisputeId == 0 && msg.sender != dispute.disputeInitiator)
            revert Errors.DisputeModule__NotDisputeInitiator();
        // for the latter - resolving is permissionless as long as the infringer dispute has been resolved
        if (dispute.infringerDisputeId > 0 && $.disputes[dispute.infringerDisputeId].currentTag != bytes32(0))
            revert Errors.DisputeModule__RelatedDisputeNotResolved();

        if (dispute.currentTag == IN_DISPUTE || dispute.currentTag == bytes32(0))
            revert Errors.DisputeModule__NotAbleToResolve();

        $.successfulDisputesPerIp[dispute.targetIpId]--;
        $.disputes[disputeId].currentTag = bytes32(0);

        IArbitrationPolicy(dispute.arbitrationPolicy).onResolveDispute(msg.sender, disputeId, data);

        emit DisputeResolved(disputeId, data);
    }

    /// @notice Updates the active arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return arbitrationPolicy The address of the arbitration policy
    function updateActiveArbitrationPolicy(address ipId) external whenNotPaused returns (address arbitrationPolicy) {
        return _updateActiveArbitrationPolicy(ipId);
    }

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool) {
        return _getDisputeModuleStorage().successfulDisputesPerIp[ipId] > 0;
    }

    /// @notice Dispute ID counter
    function disputeCounter() external view returns (uint256) {
        return _getDisputeModuleStorage().disputeCounter;
    }

    /// @notice Returns the arbitration policy cooldown
    function arbitrationPolicyCooldown() external view returns (uint256) {
        return _getDisputeModuleStorage().arbitrationPolicyCooldown;
    }

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address) {
        return _getDisputeModuleStorage().baseArbitrationPolicy;
    }

    /// @notice Returns the dispute information for a given dispute id
    /// @param disputeId The dispute id
    /// @return targetIpId The ipId that is the target of the dispute
    /// @return disputeInitiator The address of the dispute initiator
    /// @return disputeTimestamp The timestamp of the dispute
    /// @return arbitrationPolicy The address of the arbitration policy
    /// @return disputeEvidenceHash The hash pointing to the dispute evidence
    /// @return targetTag The target tag of the dispute
    /// @return currentTag The current tag of the dispute
    /// @return infringerDisputeId The infringer dispute id
    function disputes(
        uint256 disputeId
    )
        external
        view
        returns (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
            address arbitrationPolicy,
            bytes32 disputeEvidenceHash,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 infringerDisputeId
        )
    {
        Dispute memory dispute = _getDisputeModuleStorage().disputes[disputeId];
        return (
            dispute.targetIpId,
            dispute.disputeInitiator,
            dispute.disputeTimestamp,
            dispute.arbitrationPolicy,
            dispute.disputeEvidenceHash,
            dispute.targetTag,
            dispute.currentTag,
            dispute.infringerDisputeId
        );
    }

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed) {
        return _getDisputeModuleStorage().isWhitelistedDisputeTag[tag];
    }

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed) {
        return _getDisputeModuleStorage().isWhitelistedArbitrationPolicy[arbitrationPolicy];
    }

    /// @notice Returns the arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function arbitrationRelayer(address arbitrationPolicy) external view returns (address) {
        return _getDisputeModuleStorage().arbitrationRelayer[arbitrationPolicy];
    }

    /// @notice Returns the arbitration policy for a given ipId
    /// @param ipId The ipId
    function arbitrationPolicies(address ipId) external view returns (address policy) {
        return _getDisputeModuleStorage().arbitrationPolicies[ipId];
    }

    /// @notice Returns the next arbitration policy for a given ipId
    /// @param ipId The ipId
    function nextArbitrationPolicies(address ipId) external view returns (address policy) {
        return _getDisputeModuleStorage().nextArbitrationPolicies[ipId];
    }

    /// @notice Returns the next arbitration update timestamp for a given ipId
    /// @param ipId The ipId
    function nextArbitrationUpdateTimestamps(address ipId) external view returns (uint256 timestamp) {
        return _getDisputeModuleStorage().nextArbitrationUpdateTimestamps[ipId];
    }

    /// @notice Raises a dispute on a given ipId
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The id of the newly raised dispute
    function _raiseDispute(
        address targetIpId,
        address disputeInitiator,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        bytes calldata data
    ) internal returns (uint256) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!IP_ASSET_REGISTRY.isRegistered(targetIpId)) revert Errors.DisputeModule__NotRegisteredIpId();
        if (!$.isWhitelistedDisputeTag[targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();
        if (disputeEvidenceHash == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeEvidenceHash();
        if ($.isUsedEvidenceHash[disputeEvidenceHash]) revert Errors.DisputeModule__EvidenceHashAlreadyUsed();
        if (disputeInitiator == address(0) || disputeInitiator == targetIpId)
            revert Errors.DisputeModule__InvalidDisputeInitiator();

        address arbitrationPolicy = _updateActiveArbitrationPolicy(targetIpId);
        uint256 disputeId = ++$.disputeCounter;
        uint256 disputeTimestamp = block.timestamp;

        $.disputes[disputeId] = Dispute({
            targetIpId: targetIpId,
            disputeInitiator: disputeInitiator,
            disputeTimestamp: disputeTimestamp,
            arbitrationPolicy: arbitrationPolicy,
            disputeEvidenceHash: disputeEvidenceHash,
            targetTag: targetTag,
            currentTag: IN_DISPUTE,
            infringerDisputeId: 0
        });

        $.isUsedEvidenceHash[disputeEvidenceHash] = true;

        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(
            msg.sender,
            disputeInitiator,
            targetIpId,
            disputeEvidenceHash,
            targetTag,
            disputeId,
            data
        );

        emit DisputeRaised(
            disputeId,
            targetIpId,
            msg.sender,
            disputeInitiator,
            disputeTimestamp,
            arbitrationPolicy,
            disputeEvidenceHash,
            targetTag,
            data
        );

        return disputeId;
    }

    /// @notice Updates the active arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return arbitrationPolicy The address of the arbitration policy
    function _updateActiveArbitrationPolicy(address ipId) internal returns (address arbitrationPolicy) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();

        // in normal conditions the active arbitration policy is in arbitrationPolicies
        arbitrationPolicy = $.arbitrationPolicies[ipId];

        // if the next arbitration policy is set and the cooldown has passed
        // then the active arbitration policy is updated
        uint256 nextArbitrationUpdateTimestamp = $.nextArbitrationUpdateTimestamps[ipId];
        if (nextArbitrationUpdateTimestamp > 0 && nextArbitrationUpdateTimestamp < block.timestamp) {
            address nextArbitrationPolicy = $.nextArbitrationPolicies[ipId];
            $.arbitrationPolicies[ipId] = nextArbitrationPolicy;
            arbitrationPolicy = nextArbitrationPolicy;

            delete $.nextArbitrationUpdateTimestamps[ipId];
            delete $.nextArbitrationPolicies[ipId];
        }

        // if the resulting arbitration policy is not whitelisted or has been blacklisted
        // then the active arbitration policy is the base arbitration policy
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = $.baseArbitrationPolicy;
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of DisputeModule.
    function _getDisputeModuleStorage() private pure returns (DisputeModuleStorage storage $) {
        assembly {
            $.slot := DisputeModuleStorageLocation
        }
    }
}
