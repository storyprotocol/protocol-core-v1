// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { IERC20 } from "../../../../modules/royalty/policies/oppenzeppelin/IERC20.sol";

/// @title Ip pool interface
interface IIpPool is IERC20 {
    /// @notice Event emitted when a claim is made
    /// @param ipId The ipId address
    /// @param claimerIpId The claimer ipId address
    event Claimed(address ipId, address claimerIpId);

    /// @notice A function to calculate the amount of ETH claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The address of the revenue token
    /// @return The amount of revenue token claimable
    function claimableRevenue(address account, uint256 snapshotId, address token) external view returns (uint256);

    /// @notice A function for token holder to claim revenue token based on the token balance at certain snapshot
    /// @param snapshotId The snapshot id
    /// @param tokens The list of royalty tokens to claim
    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokens) external;

    /// @notice A function to claim by a list of snapshot ids
    /// @param snapshotIds The list of snapshot ids
    /// @param token The royalty token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external;

    /// @notice A function to snapshot the token balance and the claimable revenue token balance
    /// @return The snapshot id
    /// @notice Should have `require` to avoid ddos attack
    function snapshot() external returns (uint256);
}
