// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title IpRoyaltyVault interface
interface IIpRoyaltyVault {
    /// @notice Event emitted when a revenue token is added to a vault
    /// @param token The address of the revenue token
    /// @param amount The amount of revenue token added
    event RevenueTokenAddedToVault(address token, uint256 amount);

    /// @notice Event emitted when a snapshot is taken
    /// @param snapshotId The snapshot id
    /// @param snapshotTimestamp The timestamp of the snapshot
    event SnapshotCompleted(uint256 snapshotId, uint256 snapshotTimestamp);

    /// @notice Event emitted when a revenue token is claimed
    /// @param claimer The address of the claimer
    /// @param token The revenue token claimed
    /// @param amount The amount of revenue token claimed
    event RevenueTokenClaimed(address claimer, address token, uint256 amount);

    /// @notice Initializer for this implementation contract
    /// @param name The name of the royalty token
    /// @param symbol The symbol of the royalty token
    /// @param supply The total supply of the royalty token
    /// @param ipIdAddress The ip id the royalty vault belongs to
    /// @param rtReceiver The address of the royalty token receiver
    function initialize(
        string memory name,
        string memory symbol,
        uint32 supply,
        address ipIdAddress,
        address rtReceiver
    ) external;

    /// @notice Updates the vault balance with the new amount of revenue token
    /// @param token The address of the revenue token
    /// @param amount The amount of revenue token to add
    /// @dev Only callable by the royalty module or whitelisted royalty policy
    function updateVaultBalance(address token, uint256 amount) external;

    /// @notice A function to snapshot the claimable revenue and royalty token amounts
    /// @return The snapshot id
    function snapshot() external returns (uint256);

    /// @notice A function to calculate the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function claimableRevenue(address account, uint256 snapshotId, address token) external view returns (uint256);

    /// @notice Allows token holders to claim revenue token based on the token balance at certain snapshot
    /// @param snapshotId The snapshot id
    /// @param tokenList The list of revenue tokens to claim
    /// @param claimer The address of the claimer
    /// @return The amount of revenue tokens claimed for each token
    function claimRevenueOnBehalfByTokenBatch(
        uint256 snapshotId,
        address[] calldata tokenList,
        address claimer
    ) external returns (uint256[] memory);

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    /// @param claimer The address of the claimer
    /// @return The amount of revenue tokens claimed
    function claimRevenueOnBehalfBySnapshotBatch(
        uint256[] memory snapshotIds,
        address token,
        address claimer
    ) external returns (uint256);

    /// @notice Allows to claim revenue tokens on behalf of the ip royalty vault
    /// @param snapshotId The snapshot id
    /// @param tokenList The list of revenue tokens to claim
    /// @param targetIpId The target ip id to claim revenue tokens from
    function claimByTokenBatchAsSelf(uint256 snapshotId, address[] calldata tokenList, address targetIpId) external;

    /// @notice Allows to claim revenue tokens on behalf of the ip royalty vault by snapshot batch
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    /// @param targetIpId The target ip id to claim revenue tokens from
    function claimBySnapshotBatchAsSelf(uint256[] memory snapshotIds, address token, address targetIpId) external;

    /// @notice Returns the current snapshot id
    function getCurrentSnapshotId() external view returns (uint256);

    /// @notice The ip id to whom this royalty vault belongs to
    function ipId() external view returns (address);

    /// @notice The last snapshotted timestamp
    function lastSnapshotTimestamp() external view returns (uint256);

    /// @notice Amount of revenue token pending to be snapshotted
    /// @param token The address of the revenue token
    function pendingVaultAmount(address token) external view returns (uint256);

    /// @notice Amount of revenue token in the claim vault
    /// @param token The address of the revenue token
    function claimVaultAmount(address token) external view returns (uint256);

    /// @notice Amount of revenue token claimable at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param token The address of the revenue token
    function claimableAtSnapshot(uint256 snapshotId, address token) external view returns (uint256);

    /// @notice Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param claimer The address of the claimer
    /// @param token The address of the revenue token
    function isClaimedAtSnapshot(uint256 snapshotId, address claimer, address token) external view returns (bool);

    /// @notice The list of revenue tokens in the vault
    function tokens() external view returns (address[] memory);
}
