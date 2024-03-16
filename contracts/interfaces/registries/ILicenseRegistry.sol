// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import { Licensing } from "../../lib/Licensing.sol";
import { IDisputeModule } from "../modules/dispute/IDisputeModule.sol";
import { ILicensingModule } from "../modules/licensing/ILicensingModule.sol";

/// @title ILicenseRegistry
interface ILicenseRegistry is IERC1155 {
    /// @notice Emitted when a license is minted
    /// @param creator The address that created the license
    /// @param receiver The address that received the license
    /// @param licenseId The ID of the license
    /// @param amount The amount of licenses minted
    /// @param licenseData The license data
    event LicenseMinted(
        address indexed creator,
        address indexed receiver,
        uint256 indexed licenseId,
        uint256 amount,
        Licensing.License licenseData
    );

    /// @notice Returns the canonical protocol-wide LicensingModule
    function licensingModule() external view returns (ILicensingModule);

    /// @notice Returns the canonical protocol-wide DisputeModule
    function disputeModule() external view returns (IDisputeModule);

    /// @notice Mints license NFTs representing a policy granted by a set of ipIds (licensors). This NFT needs to be
    /// burned in order to link a derivative IP with its parents. If this is the first combination of policy and
    /// licensors, a new licenseId will be created. If not, the license is fungible and an id will be reused.
    /// @dev Only callable by the licensing module.
    /// @param policyId The ID of the policy to be minted
    /// @param licensorIpId_ The ID of the IP granting the license (ie. licensor)
    /// @param transferable True if the license is transferable
    /// @param amount Number of licenses to mint. License NFT is fungible for same policy and same licensors
    /// @param receiver Receiver address of the minted license NFT(s).
    /// @return licenseId The ID of the minted license NFT(s).
    function mintLicense(
        uint256 policyId,
        address licensorIpId_,
        bool transferable,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId);

    /// @notice Burns licenses
    /// @param holder The address that holds the licenses
    /// @param licenseIds The ids of the licenses to burn
    function burnLicenses(address holder, uint256[] calldata licenseIds) external;

    ///
    /// Getters
    ///

    /// @notice Returns the number of licenses registered in the protocol.
    /// @dev Token ID counter total count.
    /// @return mintedLicenses The number of minted licenses
    function mintedLicenses() external view returns (uint256);

    /// @notice Returns true if holder has positive balance for the given license ID.
    /// @return isLicensee True if holder is the licensee for the license (owner of the license NFT), or derivative IP
    /// owner if the license was added to the IP by linking (burning a license).
    function isLicensee(uint256 licenseId, address holder) external view returns (bool);

    /// @notice Returns the license data for the given license ID
    /// @param licenseId The ID of the license
    /// @return licenseData The license data
    function license(uint256 licenseId) external view returns (Licensing.License memory);

    /// @notice Returns the ID of the IP asset that is the licensor of the given license ID
    /// @param licenseId The ID of the license
    /// @return licensorIpId The ID of the licensor
    function licensorIpId(uint256 licenseId) external view returns (address);

    /// @notice Returns the policy ID for the given license ID
    /// @param licenseId The ID of the license
    /// @return policyId The ID of the policy
    function policyIdForLicense(uint256 licenseId) external view returns (uint256);

    /// @notice Returns true if the license has been revoked (licensor tagged after a dispute in
    /// the dispute module). If the tag is removed, the license is not revoked anymore.
    /// @param licenseId The id of the license to check
    /// @return isRevoked True if the license is revoked
    function isLicenseRevoked(uint256 licenseId) external view returns (bool);
}
