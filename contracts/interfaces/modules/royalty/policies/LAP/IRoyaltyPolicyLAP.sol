// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IRoyaltyPolicy } from "../../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicyLAP interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    /// @notice Transfers to vault an amount of revenue tokens claimable to LAP royalty policy
    /// @param ipId The ipId of the IP asset
    /// @param ancestorIpId The ancestor ipId of the IP asset
    /// @param token The token address to transfer
    /// @param amount The amount of tokens to transfer
    function transferToVault(address ipId, address ancestorIpId, address token, uint256 amount) external;

    /// @notice Returns the royalty percentage between an IP asset and its ancestors via LAP
    /// @param ipId The ipId to get the royalty for
    /// @param ancestorIpId The ancestor ipId to get the royalty for
    /// @return The royalty percentage between an IP asset and its ancestors via LAP
    function getPolicyRoyalty(address ipId, address ancestorIpId) external view returns (uint32);

    /// @notice Returns the total lifetime revenue tokens transferred to a vault from a descendant IP via LAP
    /// @param ipId The ipId of the IP asset
    /// @param ancestorIpId The ancestor ipId of the IP asset
    /// @param token The token address to transfer
    /// @return The total lifetime revenue tokens transferred to a vault from a descendant IP via LAP
    function getTransferredTokens(address ipId, address ancestorIpId, address token) external view returns (uint256);
}
