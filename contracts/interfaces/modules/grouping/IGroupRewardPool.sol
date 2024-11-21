// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IGroupingPolicy
/// @notice Interface for grouping policies
interface IGroupRewardPool {
    /// @notice Distributes rewards to the given IP accounts in pool
    /// @param groupId The group ID
    /// @param token The reward tokens
    /// @param ipIds The IP IDs
    function distributeRewards(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external returns (uint256[] memory rewards);

    /// @notice Deposits reward to the group pool directly
    /// @param groupId The group ID
    /// @param token The reward token
    /// @param amount The amount of reward
    function depositReward(address groupId, address token, uint256 amount) external;

    /// @notice Adds an IP to the group pool
    /// @param groupId The group ID
    /// @param ipId The IP ID
    /// @param minimumGroupRewardShare The minimum group reward share the IP expects to be added to the group
    /// @return totalGroupRewardShare The total group reward share after adding the IP
    function addIp(
        address groupId,
        address ipId,
        uint256 minimumGroupRewardShare
    ) external returns (uint256 totalGroupRewardShare);

    /// @notice Removes an IP from the group pool
    /// @param groupId The group ID
    /// @param ipId The IP ID
    function removeIp(address groupId, address ipId) external;

    /// @notice Returns the available reward for each IP in the group
    /// @param groupId The group ID
    /// @param token The reward token
    /// @param ipIds The IP IDs
    /// @return The rewards for each IP
    function getAvailableReward(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external view returns (uint256[] memory);
}
