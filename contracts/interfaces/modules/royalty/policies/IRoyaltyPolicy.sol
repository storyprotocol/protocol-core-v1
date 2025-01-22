// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IExternalRoyaltyPolicyBase } from "./IExternalRoyaltyPolicyBase.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy is IExternalRoyaltyPolicyBase {
    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licensePercent The license percentage of the license being minted
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(address ipId, uint32 licensePercent, bytes calldata externalData) external;

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseRoyaltyPolicies The royalty policies of the license
    /// @param licensesPercent The license percentages of the licenses being minted
    /// @param externalData The external data custom to each the royalty policy
    /// @return The royalty stack of the child ipId for a given royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata externalData
    ) external returns (uint32);

    /// @notice Returns the royalty stack for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return royaltyStack Sum of the royalty percentages to be paid to ancestors for a given royalty policy
    function getPolicyRoyaltyStack(address ipId) external view returns (uint32);

    /// @notice Returns the royalty policy support working with group
    /// @return True if the royalty policy support working with group otherwise false
    function isSupportGroup() external view returns (bool);
}
