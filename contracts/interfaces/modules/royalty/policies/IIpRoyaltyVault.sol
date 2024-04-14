// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title Ip royalty vault interface
interface IIpRoyaltyVault {
    /// @notice Event emitted when royalty tokens are collected
    /// @param ancestorIpId The ancestor ipId address
    /// @param royaltyTokensCollected The amount of royalty tokens collected
    event RoyaltyTokensCollected(address ancestorIpId, uint256 royaltyTokensCollected);

    /// @notice Event emitted when a snapshot is taken
    /// @param snapshotId The snapshot id
    /// @param snapshotTimestamp The timestamp of the snapshot
    /// @param unclaimedTokens The amount of unclaimed tokens at the snapshot
    event SnapshotCompleted(uint256 snapshotId, uint256 snapshotTimestamp, uint32 unclaimedTokens);

    /// @notice Event emitted when a revenue token is claimed
    /// @param claimer The address of the claimer
    /// @param token The revenue token claimed
    /// @param amount The amount of revenue token claimed
    event RevenueTokenClaimed(address claimer, address token, uint256 amount);

    /// @notice initializer for this implementation contract
    /// @param name The name of the royalty token
    /// @param symbol The symbol of the royalty token
    /// @param supply The total supply of the royalty token
    /// @param unclaimedTokens The amount of unclaimed royalty tokens reserved for ancestors
    /// @param ipIdAddress The ip id the royalty vault belongs to
    function initialize(
        string memory name,
        string memory symbol,
        uint32 supply,
        uint32 unclaimedTokens,
        address ipIdAddress
    ) external;

    /// @notice Adds a new revenue token to the vault
    /// @param token The address of the revenue token
    /// @dev Only callable by the royalty policy LAP
    /// @return Whether the token is added
    function addIpRoyaltyVaultTokens(address token) external returns (bool);

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
    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokenList) external;

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external;

    /// @notice Allows ancestors to claim the royalty tokens and any accrued revenue tokens
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function collectRoyaltyTokens(address ancestorIpId) external;

    /// @notice The ip id to whom this royalty vault belongs to
    /// @return The ip id address
    function ipId() external view returns (address);

    /// @notice The amount of unclaimed royalty tokens
    function unclaimedRoyaltyTokens() external view returns (uint32);

    /// @notice The last snapshotted timestamp
    function lastSnapshotTimestamp() external view returns (uint256);

    /// @notice The amount of revenue token in the ancestors vault
    /// @param token The address of the revenue token
    function ancestorsVaultAmount(address token) external view returns (uint256);

    /// @notice Indicates whether the ancestor has collected the royalty tokens
    /// @param ancestorIpId The ancestor ipId address
    function isCollectedByAncestor(address ancestorIpId) external view returns (bool);

    /// @notice Amount of revenue token in the claim vault
    /// @param token The address of the revenue token
    function claimVaultAmount(address token) external view returns (uint256);

    /// @notice Amount of revenue token claimable at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param token The address of the revenue token
    function claimableAtSnapshot(uint256 snapshotId, address token) external view returns (uint256);

    /// @notice Amount of unclaimed revenue tokens at the snapshot
    /// @param snapshotId The snapshot id
    function unclaimedAtSnapshot(uint256 snapshotId) external view returns (uint32);

    /// @notice Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param claimer The address of the claimer
    /// @param token The address of the revenue token
    function isClaimedAtSnapshot(uint256 snapshotId, address claimer, address token) external view returns (bool);

    /// @notice The list of revenue tokens in the vault
    function tokens() external view returns (address[] memory);
}
