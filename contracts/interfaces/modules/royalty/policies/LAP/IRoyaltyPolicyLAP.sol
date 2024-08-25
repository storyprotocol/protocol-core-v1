// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IRoyaltyPolicy } from "../../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicyLAP interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    /// @notice Event emitted when a royalty tokens are collected
    /// @param ipId The ID of the IP asset that the royalty tokens are being collected from
    /// @param ancestorIpId The ID of the ancestor that the royalty tokens are being collected for
    /// @param amount The amount of royalty tokens being collected
    event RoyaltyTokensCollected(address ipId, address ancestorIpId, uint256 amount);

    /// @notice Collects royalty tokens to an ancestor's ip royalty vault
    /// @param ipId The ID of the IP asset
    /// @param ancestorIpId The ID of the ancestor IP asset
    function collectRoyaltyTokens(address ipId, address ancestorIpId) external;

    /// @notice Allows claiming revenue tokens of behalf of royalty LAP royalty policy contract
    /// @param snapshotIds The snapshot IDs to claim revenue tokens for
    /// @param token The token to claim revenue tokens for
    /// @param targetIpId The target IP ID to claim revenue tokens for
    function claimBySnapshotBatchAsSelf(uint256[] memory snapshotIds, address token, address targetIpId) external;

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    function royaltyStack(address ipId) external view returns (uint32);

    /// @notice Returns the unclaimed royalty tokens for a given IP asset
    /// @param ipId The ipId to get the unclaimed royalty tokens for
    /// @return unclaimedRoyaltyTokens The unclaimed royalty tokens for a given ipId
    function unclaimedRoyaltyTokens(address ipId) external view returns (uint32);

    /// @notice Returns if the royalty tokens have been collected by an ancestor for a given IP asset
    /// @param ipId The ipId to check if the royalty tokens have been collected by an ancestor
    /// @param ancestorIpId The ancestor ipId to check if the royalty tokens have been collected
    /// @return isCollectedByAncestor True if the royalty tokens have been collected by an ancestor
    function isCollectedByAncestor(address ipId, address ancestorIpId) external view returns (bool);

    /// @notice Returns the revenue token balances for a given IP asset
    /// @param ipId The ipId to get the revenue token balances for
    /// @param token The token to get the revenue token balances for
    function revenueTokenBalances(address ipId, address token) external view returns (uint256);

    /// @notice Returns whether a snapshot has been claimed for a given IP asset and token
    /// @param ipId The ipId to check if the snapshot has been claimed for
    /// @param token The token to check if the snapshot has been claimed for
    /// @param snapshot The snapshot to check if it has been claimed
    /// @return True if the snapshot has been claimed
    function snapshotsClaimed(address ipId, address token, uint256 snapshot) external view returns (bool);

    /// @notice Returns the number of snapshots claimed for a given IP asset and token
    /// @param ipId The ipId to check if the snapshot has been claimed for
    /// @param token The token to check if the snapshot has been claimed for
    /// @return The number of snapshots claimed
    function snapshotsClaimedCounter(address ipId, address token) external view returns (uint256);
}
