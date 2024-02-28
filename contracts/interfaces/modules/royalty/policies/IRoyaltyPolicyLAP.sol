// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    /// @notice Initializes a royalty policy LAP for a given IP asset
    /// @param targetAncestors The expected ancestors addresses of an ipId
    /// @param targetRoyaltyAmount The expected royalties of each of the ancestors for a given ipId
    /// @param parentAncestors1 The addresses of the ancestors of the first parent
    /// @param parentAncestors2 The addresses of the ancestors of the second parent
    /// @param parentAncestorsRoyalties1 The royalties of each of the ancestors of the first parent
    /// @param parentAncestorsRoyalties2 The royalties of each of the ancestors of the second parent
    struct InitParams {
        address[] targetAncestors;
        uint32[] targetRoyaltyAmount;
        address[] parentAncestors1;
        address[] parentAncestors2;
        uint32[] parentAncestorsRoyalties1;
        uint32[] parentAncestorsRoyalties2;
    }

    /// @notice Event emitted when a policy is initialized
    /// @param ipId The ID of the IP asset that the policy is being initialized for
    /// @param splitClone The split clone address
    /// @param ancestorsVault The ancestors vault address
    /// @param royaltyStack The royalty stack
    /// @param targetAncestors The ip ancestors array
    /// @param targetRoyaltyAmount The ip royalty amount array
    event PolicyInitialized(
        address ipId,
        address splitClone,
        address ancestorsVault,
        uint32 royaltyStack,
        address[] targetAncestors,
        uint32[] targetRoyaltyAmount
    );

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return isUnlinkable Indicates if the ipId is unlinkable to new parents
    /// @return splitClone The address of the liquid split clone contract for a given ipId
    /// @return ancestorsVault The address of the ancestors vault contract for a given ipId
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @return ancestorsHash The hash of the unique ancestors addresses and royalties arrays
    function royaltyData(
        address ipId
    )
        external
        view
        returns (
            bool isUnlinkable,
            address splitClone,
            address ancestorsVault,
            uint32 royaltyStack,
            bytes32 ancestorsHash
        );

    /// @notice Returns the percentage scale - 1000 rnfts represents 100%
    function TOTAL_RNFT_SUPPLY() external view returns (uint32);

    /// @notice Returns the maximum number of parents
    function MAX_PARENTS() external view returns (uint256);

    /// @notice Returns the maximum number of total ancestors.
    /// @dev The IP derivative tree is limited to 14 ancestors, which represents 3 levels of a binary tree 14 = 2+4+8
    function MAX_ANCESTORS() external view returns (uint256);

    /// @notice Returns the RoyaltyModule address
    function ROYALTY_MODULE() external view returns (address);

    /// @notice Returns the LicensingModule address
    function LICENSING_MODULE() external view returns (address);

    /// @notice Returns the 0xSplits LiquidSplitFactory address
    function LIQUID_SPLIT_FACTORY() external view returns (address);

    /// @notice Returns the 0xSplits LiquidSplitMain address
    function LIQUID_SPLIT_MAIN() external view returns (address);

    /// @notice Returns the Ancestors Vault Implementation address
    function ANCESTORS_VAULT_IMPL() external view returns (address);

    /// @notice Distributes funds internally so that accounts holding the royalty nfts at distribution moment can
    /// claim afterwards
    /// @dev This call will revert if the caller holds all the royalty nfts of the ipId - in that case can call
    /// claimFromIpPoolAsTotalRnftOwner() instead
    /// @param ipId The ipId whose received funds will be distributed
    /// @param token The token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address (if any)
    function distributeIpPoolFunds(
        address ipId,
        address token,
        address[] calldata accounts,
        address distributorAddress
    ) external;

    /// @notice Claims the available royalties for a given address
    /// @dev If there are no funds available in split main contract but there are funds in the split clone contract
    /// then a distributeIpPoolFunds() call should precede this call
    /// @param account The account to claim for
    /// @param tokens The tokens to withdraw
    function claimFromIpPool(address account, ERC20[] calldata tokens) external;

    /// @notice Claims the available royalties for a given address that holds all the royalty nfts of an ipId
    /// @dev This call will revert if the caller does not hold all the royalty nfts of the ipId
    /// @param ipId The ipId whose received funds will be distributed
    /// @param token The token to withdraw
    function claimFromIpPoolAsTotalRnftOwner(address ipId, address token) external;

    /// @notice Claims available royalty nfts and accrued royalties for an ancestor of a given ipId
    /// @param ipId The ipId of the ancestors vault to claim from
    /// @param claimerIpId The claimer ipId is the ancestor address that wants to claim
    /// @param ancestors The ancestors for the selected ipId
    /// @param ancestorsRoyalties The royalties of the ancestors for the selected ipId
    /// @param tokens The ERC20 tokens to withdraw
    function claimFromAncestorsVault(
        address ipId,
        address claimerIpId,
        address[] calldata ancestors,
        uint32[] calldata ancestorsRoyalties,
        ERC20[] calldata tokens
    ) external;
}
