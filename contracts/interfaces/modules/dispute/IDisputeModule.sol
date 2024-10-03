// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Dispute Module Interface
interface IDisputeModule {
    /// @notice Dispute struct
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param currentTag The current tag of the dispute
    /// @param parentDisputeId The parent dispute id
    struct Dispute {
        address targetIpId;
        address disputeInitiator;
        address arbitrationPolicy;
        bytes32 disputeEvidenceHash;
        bytes32 targetTag;
        bytes32 currentTag;
        uint256 parentDisputeId;
    }

    /// @notice Event emitted when a dispute tag whitelist status is updated
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted
    event TagWhitelistUpdated(bytes32 tag, bool allowed);

    /// @notice Event emitted when an arbitration policy whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);

    /// @notice Event emitted when an arbitration relayer whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted
    event ArbitrationRelayerWhitelistUpdated(address arbitrationPolicy, address arbitrationRelayer, bool allowed);

    /// @notice Event emitted when the base arbitration policy is set
    /// @param arbitrationPolicy The address of the arbitration policy
    event DefaultArbitrationPolicyUpdated(address arbitrationPolicy);

    /// @notice Event emitted when an arbitration policy is set for an ipId
    /// @param ipId The ipId address
    /// @param arbitrationPolicy The address of the arbitration policy
    event ArbitrationPolicySet(address ipId, address arbitrationPolicy);

    /// @notice Event emitted when a dispute is raised
    /// @param disputeId The dispute id
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address disputeInitiator,
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

    /// @notice Event emitted when a derivative is tagged on a parent infringement
    /// @param parentIpId The parent ipId which infringed
    /// @param derivativeIpId The derivative ipId which was tagged
    /// @param parentDisputeId The parent dispute id in which infringement was found
    /// @param tag The tag of the dispute applied to the derivative
    event DerivativeTaggedOnParentInfringement(
        address parentIpId,
        address derivativeIpId,
        uint256 parentDisputeId,
        bytes32 tag
    );

    /// @notice Event emitted when a dispute is resolved
    /// @param disputeId The dispute id
    event DisputeResolved(uint256 disputeId);

    /// @notice Dispute ID counter
    function disputeCounter() external view returns (uint256);

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address);

    /// @notice Returns the dispute information for a given dispute id
    /// @param disputeId The dispute id
    /// @return targetIpId The ipId that is the target of the dispute
    /// @return disputeInitiator The address of the dispute initiator
    /// @return arbitrationPolicy The address of the arbitration policy
    /// @return disputeEvidenceHash The link of the dispute summary
    /// @return targetTag The target tag of the dispute
    /// @return currentTag The current tag of the dispute
    /// @return parentDisputeId The parent dispute id
    function disputes(
        uint256 disputeId
    )
        external
        view
        returns (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 disputeEvidenceHash,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        );

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    /// @return allowed Indicates if the dispute tag is whitelisted
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed);

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @return allowed Indicates if the arbitration policy is whitelisted
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed);

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @return allowed Indicates if the arbitration relayer is whitelisted
    function isWhitelistedArbitrationRelayer(
        address arbitrationPolicy,
        address arbitrationRelayer
    ) external view returns (bool allowed);

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

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(address arbitrationPolicy, address arbPolicyRelayer, bool allowed) external;

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external;

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
    /// @param parentIpId The infringing parent ipId
    /// @param derivativeIpId The derivative ipId
    /// @param parentDisputeId The dispute id that tagged the parent ipId as infringing
    function tagDerivativeIfParentInfringed(
        address parentIpId,
        address derivativeIpId,
        uint256 parentDisputeId
    ) external;

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute
    /// @param data The data to resolve the dispute
    function resolveDispute(uint256 disputeId, bytes calldata data) external;

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool);
}
