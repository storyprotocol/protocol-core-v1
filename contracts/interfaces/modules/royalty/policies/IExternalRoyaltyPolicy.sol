// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IExternalRoyaltyPolicy interface
interface IExternalRoyaltyPolicy {
    /// @notice Returns the amount of royalty tokens required to link a child to a given IP asset
    /// @param ipId The ipId of the IP asset
    /// @param licensePercent The percentage of the license
    /// @return The amount of royalty tokens required to link a child to a given IP asset
    function getPolicyRtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32);
}
