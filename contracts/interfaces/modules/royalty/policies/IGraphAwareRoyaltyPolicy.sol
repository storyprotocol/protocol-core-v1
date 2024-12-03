// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title IGraphAwareRoyaltyPolicy interface
interface IGraphAwareRoyaltyPolicy is IRoyaltyPolicy {
    /// @notice Event emitted when revenue tokens are transferred to a vault from a royalty policy
    /// @param ipId The ipId of the IP asset
    /// @param ancestorIpId The ancestor ipId of the IP asset whose vault will receive revenue tokens
    /// @param token The address of the token that is transferred
    /// @param amount The amount of tokens transferred
    event RevenueTransferredToVault(address ipId, address ancestorIpId, address token, uint256 amount);

    /// @notice Transfers to vault an amount of revenue tokens
    /// @param ipId The ipId of the IP asset
    /// @param ancestorIpId The ancestor ipId of the IP asset
    /// @param token The token address to transfer
    /// @return The amount of revenue tokens transferred
    function transferToVault(address ipId, address ancestorIpId, address token) external returns (uint256);

    /// @notice Returns the royalty percentage between an IP asset and a given ancestor
    /// @param ipId The ipId to get the royalty for
    /// @param ancestorIpId The ancestor ipId to get the royalty for
    /// @return The royalty percentage between an IP asset and a given ancestor
    function getPolicyRoyalty(address ipId, address ancestorIpId) external returns (uint32);

    /// @notice Returns the total lifetime revenue tokens transferred to an ancestor's vault from a given IP asset
    /// @param ipId The ipId of the IP asset
    /// @param ancestorIpId The ancestor ipId of the IP asset
    /// @param token The token address to transfer
    /// @return The total lifetime revenue tokens transferred to an ancestor's vault from a given IP asset
    function getTransferredTokens(address ipId, address ancestorIpId, address token) external view returns (uint256);
}
