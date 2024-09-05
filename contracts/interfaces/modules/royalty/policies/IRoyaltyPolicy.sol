// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy {
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
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata externalData
    ) external;

    /// @notice Returns the amount of royalty tokens required to link a child to a given IP asset
    /// @param ipId The ipId of the IP asset
    /// @param licensePercent The percentage of the license
    /// @return The amount of royalty tokens required to link a child to a given IP asset
    function rtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32);
}
