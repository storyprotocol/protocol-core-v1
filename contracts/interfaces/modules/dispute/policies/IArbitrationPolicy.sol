// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Arbitration Policy Interface
interface IArbitrationPolicy {
    /// @notice Executes custom logic on raising dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeInitiator Address of the dispute initiator
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to raise the dispute
    function onRaiseDispute(
        address caller,
        address disputeInitiator,
        address targetIpId,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        uint256 disputeId,
        bytes calldata data
    ) external;

    /// @notice Executes custom logic on disputing judgement
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The arbitrary data used to set the dispute judgement
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Executes custom logic on disputing cancel
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to cancel the dispute
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external;

    /// @notice Executes custom logic on resolving dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to resolve the dispute
    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external;
}
