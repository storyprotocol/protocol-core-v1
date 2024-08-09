// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IModule } from "../base/IModule.sol";

/// @title IGroupingModule
/// @notice This interface defines the entry point for users to manage group in the Story Protocol.
/// It defines the workflow of grouping actions and coordinates among all grouping components.
/// The Grouping Module is responsible for adding ip to group, removing ip from group and claiming reward.
interface IGroupingModule is IModule {
    /// @notice Emitted when added ip to group.
    /// @param groupId The address of the group.
    /// @param ipId The IP ID.
    event AddedIpToGroup(address indexed groupId, address indexed ipId);

    /// @notice Emitted when removed ip from group.
    /// @param groupId The address of the group.
    /// @param ipId The IP ID.
    event RemovedIpFromGroup(address indexed groupId, address indexed ipId);

    /// @notice Emitted when claimed reward.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipId The IP ID.
    /// @param amount The amount of reward.
    event ClaimedReward(address indexed groupId, address indexed token, address indexed ipId, uint256 amount);

    /// @notice Adds IP to group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function addIp(address groupIpId, address[] calldata ipIds) external;

    /// @notice Removes IP from group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function removeIp(address groupIpId, address[] calldata ipIds) external;

    /// @notice Claims reward.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipIds The IP IDs.
    function claimReward(address groupId, address token, address[] calldata ipIds) external;
}
