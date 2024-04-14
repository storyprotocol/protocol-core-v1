// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    /// @notice Event emitted when a policy is initialized
    /// @param ipId The ID of the IP asset that the policy is being initialized for
    /// @param ipRoyaltyVault The ip royalty vault address
    /// @param royaltyStack The royalty stack
    /// @param targetAncestors The ip ancestors array
    /// @param targetRoyaltyAmount The ip royalty amount array
    event PolicyInitialized(
        address ipId,
        address ipRoyaltyVault,
        uint32 royaltyStack,
        address[] targetAncestors,
        uint32[] targetRoyaltyAmount
    );

    /// @notice Event emitted when a revenue token is added to a vault
    /// @param token The address of the revenue token
    /// @param vault The address of the vault
    event RoyaltyTokenAddedToVault(address token, address vault);

    /// @notice The state data of the LAP royalty policy
    /// @param isUnlinkableToParents Indicates if the ipId is unlinkable to new parents
    /// @param ipRoyaltyVault The ip royalty vault address
    /// @param royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @param ancestorsAddresses The ancestors addresses array
    /// @param ancestorsRoyalties Contains royalty token amounts for each ancestor on same index as ancestorsAddresses
    struct LAPRoyaltyData {
        bool isUnlinkableToParents;
        address ipRoyaltyVault;
        uint32 royaltyStack;
        address[] ancestorsAddresses;
        uint32[] ancestorsRoyalties;
    }

    /// @notice Returns the percentage scale - represents 100% of royalty tokens for an ip
    function TOTAL_RT_SUPPLY() external view returns (uint32);

    /// @notice Returns the maximum number of parents
    function MAX_PARENTS() external view returns (uint256);

    /// @notice Returns the maximum number of total ancestors.
    /// @dev The IP derivative tree is limited to 14 ancestors, which represents 3 levels of a binary tree 14 = 2+4+8
    function MAX_ANCESTORS() external view returns (uint256);

    /// @notice Returns the RoyaltyModule address
    function ROYALTY_MODULE() external view returns (address);

    /// @notice Returns the LicensingModule address
    function LICENSING_MODULE() external view returns (address);

    /// @notice Returns the snapshot interval
    function getSnapshotInterval() external view returns (uint256);

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return isUnlinkable Indicates if the ipId is unlinkable to new parents
    /// @return ipRoyaltyVault The ip royalty vault address
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @return targetAncestors The ip ancestors array
    /// @return targetRoyaltyAmount The ip royalty amount array
    function getRoyaltyData(
        address ipId
    ) external view returns (bool, address, uint32, address[] memory, uint32[] memory);
}
