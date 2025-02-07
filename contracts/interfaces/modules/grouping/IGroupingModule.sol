// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "../base/IModule.sol";

/// @title IGroupingModule
/// @notice This interface defines the entry point for users to manage group in the Story Protocol.
/// It defines the workflow of grouping actions and coordinates among all grouping components.
/// The Grouping Module is responsible for adding ip to group, removing ip from group and claiming reward.
interface IGroupingModule is IModule {
    /// @notice Emitted when a group is registered.
    /// @param groupId The address of the group.
    /// @param groupPool The address of the group pool.
    event IPGroupRegistered(address indexed groupId, address indexed groupPool);

    /// @notice Emitted when added ip to group.
    /// @param groupId The address of the group.
    /// @param ipIds The IP ID.
    event AddedIpToGroup(address indexed groupId, address[] ipIds);

    /// @notice Emitted when removed ip from group.
    /// @param groupId The address of the group.
    /// @param ipIds The IP ID.
    event RemovedIpFromGroup(address indexed groupId, address[] ipIds);

    /// @notice Emitted when claimed reward.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipId The IP ID.
    /// @param amount The amount of reward.
    event ClaimedReward(address indexed groupId, address indexed token, address[] ipId, uint256[] amount);

    /// @notice Emitted when collected royalties into the group pool.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param pool The address of the pool.
    /// @param amount The amount of reward.
    event CollectedRoyaltiesToGroupPool(
        address indexed groupId,
        address indexed token,
        address indexed pool,
        uint256 amount
    );

    /// @notice Registers a Group IPA.
    /// @param groupPool The address of the group pool.
    /// @return groupId The address of the newly registered Group IPA.
    function registerGroup(address groupPool) external returns (address groupId);

    /// @notice Whitelists a group reward pool.
    /// @param rewardPool The address of the group reward pool.
    /// @param allowed Whether the group reward pool is whitelisted.
    function whitelistGroupRewardPool(address rewardPool, bool allowed) external;

    /// @notice Adds IP to group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    /// @param maxAllowedRewardShare The maximum reward share percentage that can be allocated to each member IP.
    function addIp(address groupIpId, address[] calldata ipIds, uint256 maxAllowedRewardShare) external;

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

    /// @notice Collects royalties into the pool, making them claimable by group member IPs.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    function collectRoyalties(address groupId, address token) external returns (uint256 royalties);

    /// @notice Returns the available reward for each IP in the group.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipIds The IP IDs.
    /// @return The rewards for each IP.
    function getClaimableReward(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external view returns (uint256[] memory);
}
