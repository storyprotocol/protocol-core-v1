// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicyLAP } from "./IRoyaltyPolicyLAP.sol";

/// @title Liquid absolute percentage policy ancestor vault interface
interface IAncestorsVaultLAP {
    /// @notice Event emitted when a claim is made
    /// @param ipId The ipId address
    /// @param claimerIpId The claimer ipId address
    /// @param tokens The ERC20 tokens to withdraw
    event Claimed(address ipId, address claimerIpId, ERC20[] tokens);

    /// @notice Returns the canonical RoyaltyPolicyLAP
    function ROYALTY_POLICY_LAP() external view returns (IRoyaltyPolicyLAP);

    /// @notice Claims all available royalty nfts and accrued royalties for an ancestor of a given ipId
    /// @param ipId The ipId of the ancestors vault to claim from
    /// @param claimerIpId The claimer ipId is the ancestor address that wants to claim
    /// @param ancestors The ancestors for the selected ipId
    /// @param ancestorsRoyalties The royalties of the ancestors for the selected ipId
    /// @param tokens The ERC20 tokens to withdraw
    function claim(
        address ipId,
        address claimerIpId,
        address[] calldata ancestors,
        uint32[] calldata ancestorsRoyalties,
        ERC20[] calldata tokens
    ) external;
}
