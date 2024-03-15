// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";

import { DISPUTE_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../../modules/BaseModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { IIPAssetRegistry } from "../../interfaces/registries/IIPAssetRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { Errors } from "../../lib/Errors.sol";
import { ShortStringOps } from "../../utils/ShortStringOps.sol";

/// @title Dispute Module
/// @notice The dispute module acts as an enforcement layer for IP assets that allows raising and resolving disputes
/// through arbitration by judges.
contract DisputeModule is IDisputeModule, BaseModule, AccessManaged, ReentrancyGuard, AccessControlled {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    string public constant override name = DISPUTE_MODULE_KEY;

    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    /// @notice Protocol-wide IP asset registry
    IIPAssetRegistry public IP_ASSET_REGISTRY;

    /// @notice Dispute ID counter
    uint256 public disputeCounter;

    /// @notice The address of the base arbitration policy
    address public baseArbitrationPolicy;

    /// @notice Returns the dispute information for a given dispute id
    mapping(uint256 disputeId => Dispute dispute) public disputes;

    /// @notice Indicates if a dispute tag is whitelisted
    mapping(bytes32 tag => bool allowed) public isWhitelistedDisputeTag;

    /// @notice Indicates if an arbitration policy is whitelisted
    mapping(address arbitrationPolicy => bool allowed) public isWhitelistedArbitrationPolicy;

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    mapping(address arbitrationPolicy => mapping(address arbitrationRelayer => bool allowed))
        public isWhitelistedArbitrationRelayer;

    /// @notice Arbitration policy for a given ipId
    mapping(address ipId => address arbitrationPolicy) public arbitrationPolicies;

    /// @dev Counter of successful disputes per ipId
    /// @dev BETA feature, for mainnet tag semantics must influence effect in other modules. For now
    /// any successful dispute will affect the IP protocol wide
    mapping(address ipId => uint256) private successfulDisputesPerIp;

    constructor(
        address _controller,
        address _assetRegistry,
        address _manager
    ) AccessManaged(_manager) AccessControlled(_controller, _assetRegistry) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(_assetRegistry);
    }

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external restricted {
        if (tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();

        isWhitelistedDisputeTag[tag] = allowed;

        emit TagWhitelistUpdated(tag, allowed);
    }

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external restricted {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        isWhitelistedArbitrationPolicy[arbitrationPolicy] = allowed;

        emit ArbitrationPolicyWhitelistUpdated(arbitrationPolicy, allowed);
    }

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(
        address arbitrationPolicy,
        address arbPolicyRelayer,
        bool allowed
    ) external restricted {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();
        if (arbPolicyRelayer == address(0)) revert Errors.DisputeModule__ZeroArbitrationRelayer();

        isWhitelistedArbitrationRelayer[arbitrationPolicy][arbPolicyRelayer] = allowed;

        emit ArbitrationRelayerWhitelistUpdated(arbitrationPolicy, arbPolicyRelayer, allowed);
    }

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external restricted {
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        baseArbitrationPolicy = arbitrationPolicy;

        emit DefaultArbitrationPolicyUpdated(arbitrationPolicy);
    }

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address ipId, address arbitrationPolicy) external verifyPermission(ipId) {
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        arbitrationPolicies[ipId] = arbitrationPolicy;

        emit ArbitrationPolicySet(ipId, arbitrationPolicy);
    }

    /// @notice Raises a dispute on a given ipId
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The id of the newly raised dispute
    function raiseDispute(
        address targetIpId,
        string memory linkToDisputeEvidence,
        bytes32 targetTag,
        bytes calldata data
    ) external nonReentrant returns (uint256) {
        if (!IP_ASSET_REGISTRY.isRegistered(targetIpId)) revert Errors.DisputeModule__NotRegisteredIpId();
        if (!isWhitelistedDisputeTag[targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        bytes32 linkToDisputeEvidenceBytes = ShortStringOps.stringToBytes32(linkToDisputeEvidence);
        if (linkToDisputeEvidenceBytes == bytes32(0)) revert Errors.DisputeModule__ZeroLinkToDisputeEvidence();

        address arbitrationPolicy = arbitrationPolicies[targetIpId];
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = baseArbitrationPolicy;

        uint256 disputeId_ = ++disputeCounter;

        disputes[disputeId_] = Dispute({
            targetIpId: targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidenceBytes,
            targetTag: targetTag,
            currentTag: IN_DISPUTE
        });

        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(msg.sender, data);

        emit DisputeRaised(
            disputeId_,
            targetIpId,
            msg.sender,
            arbitrationPolicy,
            linkToDisputeEvidenceBytes,
            targetTag,
            data
        );

        return disputeId_;
    }

    /// @notice Sets the dispute judgement on a given dispute. Only whitelisted arbitration relayers can call to judge.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external nonReentrant {
        Dispute memory dispute = disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (!isWhitelistedArbitrationRelayer[dispute.arbitrationPolicy][msg.sender]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationRelayer();
        }

        if (decision) {
            disputes[disputeId].currentTag = dispute.targetTag;
            successfulDisputesPerIp[dispute.targetIpId]++;
        } else {
            disputes[disputeId].currentTag = bytes32(0);
        }

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeJudgement(disputeId, decision, data);

        emit DisputeJudgementSet(disputeId, decision, data);
    }

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external nonReentrant {
        Dispute memory dispute = disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, disputeId, data);

        disputes[disputeId].currentTag = bytes32(0);

        emit DisputeCancelled(disputeId, data);
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute id
    function resolveDispute(uint256 disputeId) external {
        Dispute memory dispute = disputes[disputeId];

        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();
        if (dispute.currentTag == IN_DISPUTE || dispute.currentTag == bytes32(0))
            revert Errors.DisputeModule__NotAbleToResolve();

        successfulDisputesPerIp[dispute.targetIpId]--;
        disputes[disputeId].currentTag = bytes32(0);

        emit DisputeResolved(disputeId);
    }

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool) {
        return successfulDisputesPerIp[ipId] > 0;
    }
}
