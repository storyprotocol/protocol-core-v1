// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.23;

import { BaseLicenseTemplateUpgradeable } from "contracts/modules/licensing/BaseLicenseTemplateUpgradeable.sol";

contract MockLicenseTemplate is BaseLicenseTemplateUpgradeable {
    uint32 public licenseTermsCounter;
    mapping(uint32 => bool) public licenseTerms;

    function registerLicenseTerms() external returns (uint32 id) {
        id = licenseTermsCounter++;
        licenseTerms[id] = true;
    }

    /// @notice Checks if a license terms exists.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms exists, false otherwise.
    function exists(uint32 licenseTermsId) external view override returns (bool) {
        return licenseTerms[licenseTermsId];
    }

    /// @notice Verifies the minting of a license token.
    /// @dev the function will be called by the LicensingModule when minting a license token to
    /// verify the minting is whether allowed by the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee who will receive the license token.
    /// @param licensorIpId The IP ID of the licensor who attached the license terms minting the license token.
    /// @return True if the minting is verified, false otherwise.
    function verifyMintLicenseToken(
        uint32 licenseTermsId,
        address licensee,
        address licensorIpId,
        uint256 amount
    ) external override returns (bool) {
        return true;
    }

    /// @notice Verifies the registration of a derivative.
    /// @dev This function is invoked by the LicensingModule during the registration of a derivative work
    //// to ensure compliance with the parent IP's licensing terms.
    /// It verifies whether the derivative's registration is permitted under those terms.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpId The IP ID of the parent.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivative(
        address childIpId,
        address parentIpId,
        uint32 licenseTermsId,
        address licensee
    ) external override returns (bool) {
        return true;
    }

    /// @notice Verifies if the licenses are compatible.
    /// @dev This function is called by the LicensingModule to verify license compatibility
    /// when registering a derivative IP to multiple parent IPs.
    /// It ensures that the licenses of all parent IPs are compatible with each other during the registration process.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return True if the licenses are compatible, false otherwise.
    function verifyCompatibleLicenses(uint32[] calldata licenseTermsIds) external view override returns (bool) {
        return true;
    }

    /// @notice Verifies the registration of a derivative for all parent IPs.
    /// @dev This function is called by the LicensingModule to verify licenses for registering a derivative IP
    /// to multiple parent IPs.
    /// the function will verify the derivative for each parent IP's license and
    /// also verify all licenses are compatible.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpIds The IP IDs of the parents.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param childIpOwner The address of the derivative IP owner.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivativeForAllParents(
        address childIpId,
        address[] calldata parentIpIds,
        uint32[] calldata licenseTermsIds,
        address childIpOwner
    ) external override returns (bool) {
        return true;
    }

    /// @notice Returns the royalty policy of a license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return royaltyPolicy The address of the royalty policy specified for the license terms.
    /// @return royaltyData The data of the royalty policy.
    /// @return mintingFee The fee for minting a license.
    /// @return currency The address of the ERC20 token, used for minting license fee and royalties.
    /// the currency token will used for pay for license token minting fee and royalties.
    function getRoyaltyPolicy(
        uint32 licenseTermsId
    ) external view returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingFee, address currency) {
        return (address(0), "", 0, address(0));
    }

    /// @notice Checks if a license terms is transferable.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms is transferable, false otherwise.
    function isLicenseTransferable(uint32 licenseTermsId) external view override returns (bool) {
        return true;
    }

    /// @notice Returns the earliest expiration time among the given license terms.
    /// @param start The start time.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return The earliest expiration time.
    function getEarlierExpireTime(
        uint32[] calldata licenseTermsIds,
        uint40 start
    ) external view override returns (uint40) {
        return 0;
    }

    /// @notice Returns the expiration time of a license terms.
    /// @param start The start time.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The expiration time.
    function getExpireTime(uint32 licenseTermsId, uint40 start) external view returns (uint40) {
        return 0;
    }

    /// @notice Returns the total number of registered license terms.
    /// @return The total number of registered license terms.
    function totalRegisteredLicenseTerms() external view returns (uint32) {
        return licenseTermsCounter;
    }

    /// @notice checks the contract whether supports the given interface.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(BaseLicenseTemplateUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Converts the license terms to a JSON string which will be part of the metadata of license token.
    /// @dev Must return OpenSea standard compliant metadata.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The JSON string of the license terms, follow the OpenSea metadata standard.
    function toJson(uint32 licenseTermsId) public view returns (string memory) {
        return "";
    }

    /// @notice Returns the URI of the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The URI of the license terms.
    function getLicenseTermsURI(uint32 licenseTermsId) external view returns (string memory) {
        return "";
    }
}
