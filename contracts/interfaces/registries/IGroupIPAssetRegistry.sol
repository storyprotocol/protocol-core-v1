// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Interface for Group IPA  Registry
/// @notice This interface manages the registration and tracking of Group IPA
interface IGroupIPAssetRegistry {
    /// @notice Registers a Group IPA
    /// @param groupNft The address of the group IPA
    /// @param groupNftId The id of the group IPA
    /// @param rewardPool The address of the group reward pool
    /// @return groupId The address of the newly registered Group IPA.
    function registerGroup(address groupNft, uint256 groupNftId, address rewardPool) external returns (address groupId);

    /// @notice Whitelists a group reward pool
    /// @param rewardPool The address of the group reward pool
    function whitelistGroupRewardPool(address rewardPool) external;

    /// @notice Adds a member to a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @param ipIds The addresses of the IPs to add to the Group IPA.
    function addGroupMember(address groupId, address[] calldata ipIds) external;

    /// @notice Removes a member from a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @param ipIds The addresses of the IPs to remove from the Group IPA.
    function removeGroupMember(address groupId, address[] calldata ipIds) external;

    /// @notice Checks whether a group IPA was registered based on its ID.
    /// @param groupId The address of the Group IPA.
    /// @return isRegistered Whether the Group IPA was registered into the protocol.
    function isRegisteredGroup(address groupId) external view returns (bool);

    /// @notice Retrieves the group policy for a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @return groupPool The address of the group policy.
    function getGroupRewardPool(address groupId) external view returns (address);

    /// @notice Retrieves the group members for a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @param startIndex The start index of the group members to retrieve
    /// @param size The size of the group members to retrieve
    /// @return groupMembers The addresses of the group members
    function getGroupMembers(
        address groupId,
        uint256 startIndex,
        uint256 size
    ) external view returns (address[] memory);

    /// @notice Checks whether an IP is a member of a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @param ipId The address of the IP.
    /// @return isMember Whether the IP is a member of the Group IPA.
    function containsIp(address groupId, address ipId) external view returns (bool);

    /// @notice Retrieves the total number of members in a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @return totalMembers The total number of members in the Group IPA.
    function totalMembers(address groupId) external view returns (uint256);
}
