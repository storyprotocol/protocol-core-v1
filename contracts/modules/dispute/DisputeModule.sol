// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

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
contract DisputeModule is
    IDisputeModule,
    BaseModule,
    AccessManagedUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlled,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev Storage for DisputeModule
    /// @param disputeCounter The dispute ID counter
    /// @param baseArbitrationPolicy The address of the base arbitration policy
    /// @param disputes Returns the dispute information for a given dispute id
    /// @param isWhitelistedDisputeTag Indicates if a dispute tag is whitelisted
    /// @param isWhitelistedArbitrationPolicy Indicates if an arbitration policy is whitelisted
    /// @param isWhitelistedArbitrationRelayer Indicates if an arbitration relayer
    /// is whitelisted for a given arbitration policy
    /// @param arbitrationPolicies Arbitration policy for a given ipId
    /// @param successfulDisputesPerIp Counter of successful disputes per ipId
    /// @custom:storage-location erc7201:story-protocol.DisputeModule
    struct DisputeModuleStorage {
        uint256 disputeCounter;
        address baseArbitrationPolicy;
        mapping(uint256 => Dispute) disputes;
        mapping(bytes32 => bool) isWhitelistedDisputeTag;
        mapping(address => bool) isWhitelistedArbitrationPolicy;
        mapping(address => mapping(address => bool)) isWhitelistedArbitrationRelayer;
        mapping(address => address) arbitrationPolicies;
        mapping(address => uint256) successfulDisputesPerIp;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.DisputeModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DisputeModuleStorageLocation =
        0x682945c2d364b4630e68ffe0854d372acb0c4ff549a1e3dbc6f878bd8da0c800;

    string public constant override name = DISPUTE_MODULE_KEY;

    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    /// @notice Protocol-wide IP asset registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// Constructor
    /// @param controller The address of the access controller
    /// @param assetRegistry The address of the asset registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address controller, address assetRegistry) AccessControlled(controller, assetRegistry) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(assetRegistry);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external restricted {
        if (tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();

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
        $.isWhitelistedArbitrationPolicy[arbitrationPolicy] = allowed;

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

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.isWhitelistedArbitrationRelayer[arbitrationPolicy][arbPolicyRelayer] = allowed;

        emit ArbitrationRelayerWhitelistUpdated(arbitrationPolicy, arbPolicyRelayer, allowed);
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

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address ipId, address arbitrationPolicy) external verifyPermission(ipId) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        $.arbitrationPolicies[ipId] = arbitrationPolicy;

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
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedDisputeTag[targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        bytes32 linkToDisputeEvidenceBytes = ShortStringOps.stringToBytes32(linkToDisputeEvidence);
        if (linkToDisputeEvidenceBytes == bytes32(0)) revert Errors.DisputeModule__ZeroLinkToDisputeEvidence();

        address arbitrationPolicy = $.arbitrationPolicies[targetIpId];
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = $.baseArbitrationPolicy;

        uint256 disputeId = ++$.disputeCounter;

        $.disputes[disputeId] = Dispute({
            targetIpId: targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidenceBytes,
            targetTag: targetTag,
            currentTag: IN_DISPUTE
        });

        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(msg.sender, data);

        emit DisputeRaised(
            disputeId,
            targetIpId,
            msg.sender,
            arbitrationPolicy,
            linkToDisputeEvidenceBytes,
            targetTag,
            data
        );

        return disputeId;
    }

    /// @notice Sets the dispute judgement on a given dispute. Only whitelisted arbitration relayers can call to judge.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external nonReentrant {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();

        Dispute memory dispute = $.disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (!$.isWhitelistedArbitrationRelayer[dispute.arbitrationPolicy][msg.sender]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationRelayer();
        }

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
    function cancelDispute(uint256 disputeId, bytes calldata data) external nonReentrant {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        Dispute memory dispute = $.disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, disputeId, data);

        $.disputes[disputeId].currentTag = bytes32(0);

        emit DisputeCancelled(disputeId, data);
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute id
    function resolveDispute(uint256 disputeId) external {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        Dispute memory dispute = $.disputes[disputeId];

        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();
        if (dispute.currentTag == IN_DISPUTE || dispute.currentTag == bytes32(0))
            revert Errors.DisputeModule__NotAbleToResolve();

        $.successfulDisputesPerIp[dispute.targetIpId]--;
        $.disputes[disputeId].currentTag = bytes32(0);

        emit DisputeResolved(disputeId);
    }

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.successfulDisputesPerIp[ipId] > 0;
    }

    /// @notice Dispute ID counter
    function disputeCounter() external view returns (uint256) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.disputeCounter;
    }

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.baseArbitrationPolicy;
    }

    /// @notice Returns the dispute information for a given dispute id
    /// @param disputeId The dispute id
    /// @return targetIpId The ipId that is the target of the dispute
    /// @return disputeInitiator The address of the dispute initiator
    /// @return arbitrationPolicy The address of the arbitration policy
    /// @return linkToDisputeEvidence The link of the dispute summary
    /// @return targetTag The target tag of the dispute
    /// @return currentTag The current tag of the dispute
    function disputes(
        uint256 disputeId
    )
        external
        view
        returns (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag
        )
    {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return (
            $.disputes[disputeId].targetIpId,
            $.disputes[disputeId].disputeInitiator,
            $.disputes[disputeId].arbitrationPolicy,
            $.disputes[disputeId].linkToDisputeEvidence,
            $.disputes[disputeId].targetTag,
            $.disputes[disputeId].currentTag
        );
    }

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    /// @return allowed Indicates if the dispute tag is whitelisted
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.isWhitelistedDisputeTag[tag];
    }

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @return allowed Indicates if the arbitration policy is whitelisted
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.isWhitelistedArbitrationPolicy[arbitrationPolicy];
    }

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @return allowed Indicates if the arbitration relayer is whitelisted
    function isWhitelistedArbitrationRelayer(
        address arbitrationPolicy,
        address arbitrationRelayer
    ) external view returns (bool allowed) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.isWhitelistedArbitrationRelayer[arbitrationPolicy][arbitrationRelayer];
    }

    /// @notice Arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return policy The address of the arbitration policy
    function arbitrationPolicies(address ipId) external view returns (address policy) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.arbitrationPolicies[ipId];
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
