// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Dispute Module Interface
interface IDisputeModule {
    /// @notice Dispute struct
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param disputeTimestamp The timestamp of the dispute
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param currentTag The current tag of the dispute
    /// @param infringerDisputeId The infringer dispute id
    struct Dispute {
        address targetIpId;
        address disputeInitiator;
        uint256 disputeTimestamp;
        address arbitrationPolicy;
        bytes32 disputeEvidenceHash;
        bytes32 targetTag;
        bytes32 currentTag;
        uint256 infringerDisputeId;
    }

    /// @notice Event emitted when a dispute tag whitelist status is updated
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted
    event TagWhitelistUpdated(bytes32 tag, bool allowed);

    /// @notice Event emitted when an arbitration policy whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);

    /// @notice Event emitted when an arbitration relayer address is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    event ArbitrationRelayerUpdated(address arbitrationPolicy, address arbitrationRelayer);

    /// @notice Event emitted when the base arbitration policy is set
    /// @param arbitrationPolicy The address of the arbitration policy
    event DefaultArbitrationPolicyUpdated(address arbitrationPolicy);

    /// @notice Event emitted when the arbitration policy cooldown is updated
    /// @param cooldown The cooldown in seconds
    event ArbitrationPolicyCooldownUpdated(uint256 cooldown);

    /// @notice Event emitted when an arbitration policy is set for an ipId
    /// @param ipId The ipId address
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param nextArbitrationUpdateTimestamp The timestamp of the next arbitration update
    event ArbitrationPolicySet(address ipId, address arbitrationPolicy, uint256 nextArbitrationUpdateTimestamp);

    /// @notice Event emitted when a dispute is raised
    /// @param disputeId The dispute id
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param caller The address of the caller
    /// @param disputeInitiator The address of the dispute initiator
    /// @param disputeTimestamp The timestamp of the dispute
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address caller,
        address disputeInitiator,
        uint256 disputeTimestamp,
        address arbitrationPolicy,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        bytes data
    );

    /// @notice Event emitted when a dispute judgement is set
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeJudgementSet(uint256 disputeId, bool decision, bytes data);

    /// @notice Event emitted when a dispute is cancelled
    /// @param disputeId The dispute id
    /// @param data Custom data adjusted to each policy
    event DisputeCancelled(uint256 disputeId, bytes data);

    /// @notice Event emitted when a derivative is tagged if a parent infringed
    /// or a group ip is taggedif a group member infringed
    /// @param disputeId The dispute id
    /// @param infringingIpId The ipId which infringed
    /// @param ipIdToTag The ipId which was tagged
    /// @param infringerDisputeId The dispute id in which infringement was found
    /// @param tag The tag of the dispute applied to the ipIdToTag
    /// @param disputeTimestamp The timestamp of the dispute
    event IpTaggedOnRelatedIpInfringement(
        uint256 disputeId,
        address infringingIpId,
        address ipIdToTag,
        uint256 infringerDisputeId,
        bytes32 tag,
        uint256 disputeTimestamp
    );

    /// @notice Event emitted when a dispute is resolved
    /// @param disputeId The dispute id
    /// @param data Custom data adjusted to each policy
    event DisputeResolved(uint256 disputeId, bytes data);

    /// @notice Dispute ID counter
    function disputeCounter() external view returns (uint256);

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address);

    /// @notice Returns the dispute information for a given dispute id
    /// @param disputeId The dispute id
    /// @return targetIpId The ipId that is the target of the dispute
    /// @return disputeInitiator The address of the dispute initiator
    /// @return disputeTimestamp The timestamp of the dispute
    /// @return arbitrationPolicy The address of the arbitration policy
    /// @return disputeEvidenceHash The link of the dispute summary
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
        );

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    /// @return allowed Indicates if the dispute tag is whitelisted
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed);

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @return allowed Indicates if the arbitration policy is whitelisted
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed);

    /// @notice Returns the arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @return arbitrationRelayer The address of the arbitration relayer
    function arbitrationRelayer(address arbitrationPolicy) external view returns (address arbitrationRelayer);

    /// @notice Arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return policy The address of the arbitration policy
    function arbitrationPolicies(address ipId) external view returns (address policy);

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external;

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external;

    /// @notice Sets the arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    function setArbitrationRelayer(address arbitrationPolicy, address arbPolicyRelayer) external;

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external;

    /// @notice Sets the arbitration policy cooldown
    /// @param cooldown The cooldown in seconds
    function setArbitrationPolicyCooldown(uint256 cooldown) external;

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address ipId, address arbitrationPolicy) external;

    /// @notice Raises a dispute on a given ipId
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to raise a dispute
    /// @return disputeId The id of the newly raised dispute
    function raiseDispute(
        address targetIpId,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        bytes calldata data
    ) external returns (uint256 disputeId);

    /// @notice Sets the dispute judgement on a given dispute. Only whitelisted arbitration relayers can call to judge.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external;

    /// @notice Tags a derivative if a parent has been tagged with an infringement tag
    /// or a group ip if a group member has been tagged with an infringement tag
    /// @param ipIdToTag The ipId to tag
    /// @param infringerDisputeId The dispute id that tagged the related infringing ipId
    function tagIfRelatedIpInfringed(address ipIdToTag, uint256 infringerDisputeId) external;

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute
    /// @param data The data to resolve the dispute
    function resolveDispute(uint256 disputeId, bytes calldata data) external;

    /// @notice Updates the active arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return arbitrationPolicy The address of the arbitration policy
    function updateActiveArbitrationPolicy(address ipId) external returns (address arbitrationPolicy);

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool);
}
