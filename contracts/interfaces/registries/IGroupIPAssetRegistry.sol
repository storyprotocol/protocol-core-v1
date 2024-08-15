// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Interface for Group IPA  Registry
/// @notice This interface manages the registration and tracking of Group IPA
interface IGroupIPAssetRegistry {
    /// @notice Emits when a Group IPA is officially registered into the protocol.
    /// @param groupId The address of the registered Group IPA.
    /// @param chainId The chain identifier of where the Group NFT resides.
    /// @param tokenContract The token contract address of the Group NFT.
    /// @param tokenId The token ID of the Group NFT.
    event IPGroupRegistered(
        address groupId,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address indexed groupPolicy
    );

    /// @notice Registers a Group IPA
    /// @param groupPolicy The address of the group policy
    /// @return groupId The address of the newly registered Group IPA.
    function registerGroup(address groupPolicy) external returns (address groupId);

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
    function isGroupRegistered(address groupId) external view returns (bool);

    /// @notice Retrieves the group policy for a Group IPA
    /// @param groupId The address of the Group IPA.
    /// @return groupPolicy The address of the group policy.
    function getGroupPolicy(address groupId) external view returns (address);

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
