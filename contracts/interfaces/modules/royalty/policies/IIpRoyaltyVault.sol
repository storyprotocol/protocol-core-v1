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
    function addIpRoyaltyVaultTokens(address token) external;

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
    /// @param tokens The list of revenue tokens to claim
    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokens) external;

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external;

    /// @notice Allows ancestors to claim the royalty tokens and any accrued revenue tokens
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function collectRoyaltyTokens(address ancestorIpId) external;

    /// @notice Returns the list of revenue tokens in the vault
    /// @return The list of revenue tokens
    function getVaultTokens() external view returns (address[] memory);
}
