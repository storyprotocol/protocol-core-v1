// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title ILicenseTemplate
/// @notice This interface defines the methods for a License Template.
interface ILicenseTemplate is IERC165 {
    /// @notice Emitted when a new license terms is registered.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTerms The data of the license.
    event LicenseTermsRegistered(uint256 indexed licenseTermsId, address indexed licenseTemplate, bytes licenseTerms);

    /// @notice Returns the name of the license template.
    /// @return The name of the license template.
    function name() external view returns (string memory);

    /// @notice Converts the license terms to a JSON string.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The JSON string of the license terms.
    function toJson(uint256 licenseTermsId) external view returns (string memory);

    /// @notice Returns the metadata URI of the license template.
    /// @return The metadata URI of the license template.
    function getMetadataURI() external view returns (string memory);

    /// @notice Returns the total number of registered license terms.
    /// @return The total number of registered license terms.
    function totalRegisteredLicenseTerms() external view returns (uint256);

    /// @notice Checks if a license terms exists.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms exists, false otherwise.
    function exists(uint256 licenseTermsId) external view returns (bool);

    /// @notice Checks if a license terms is transferable.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms is transferable, false otherwise.
    function isTransferable(uint256 licenseTermsId) external view returns (bool);

    /// @notice Returns the earliest expiration time among the given license terms.
    /// @param start The start time.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return The earliest expiration time.
    function getEarlierExpireTime(uint256 start, uint256[] calldata licenseTermsIds) external view returns (uint);

    /// @notice Returns the expiration time of a license terms.
    /// @param start The start time.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The expiration time.
    function getExpireTime(uint256 start, uint256 licenseTermsId) external view returns (uint);

    /// @notice Returns the royalty policy of a license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return royaltyPolicy The address of the royalty policy.
    /// @return royaltyData The data of the royalty policy.
    /// @return mintingLicenseFee The fee for minting a license.
    /// @return currencyToken The address of the currency token.
    function getRoyaltyPolicy(
        uint256 licenseTermsId
    )
    external
    view
    returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingLicenseFee, address currencyToken);

    /// @notice Verifies the minting of a license token.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee.
    /// @param licensorIpId The IP ID of the licensor.
    /// @param mintAmount The amount of licenses to mint.
    /// @return True if the minting is verified, false otherwise.
    function verifyMintLicenseToken(
        uint256 licenseTermsId,
        address licensee,
        address licensorIpId,
        uint256 mintAmount
    ) external returns (bool);

    /// @notice Verifies the registration of a derivative.
    /// @param derivativeIpId The IP ID of the derivative.
    /// @param originalIpId The IP ID of the original.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivative(
        address derivativeIpId,
        address originalIpId,
        uint256 licenseTermsId,
        address licensee
    ) external returns (bool);

    /// @notice Verifies if the licenses are compatible.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return True if the licenses are compatible, false otherwise.
    function verifyCompatibleLicenses(uint256[] calldata licenseTermsIds) external view returns (bool);

    /// @notice Verifies the registration of a derivative for all original IPs.
    /// @param derivativeIpId The IP ID of the derivative.
    /// @param originalIpId The IP IDs of the originals.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param derivativeIpOwner The address of the derivative IP owner.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivativeForAll(
        address derivativeIpId,
        address[] calldata originalIpId,
        uint256[] calldata licenseTermsIds,
        address derivativeIpOwner
    ) external returns (bool);
}