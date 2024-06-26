// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title ILicenseToken
/// @notice Interface for the License Token (ERC721) NFT collection that manages License Tokens representing
/// License Terms.
/// Each License Token may represent a set of License Terms.
/// License Tokens are ERC721 NFTs that can be minted, transferred (if allowed), and burned.
/// Derivative IP owners can burn License Tokens to register their IP as a derivative of the licensor IP for which
/// the License Token was minted.
/// This interface includes functionalities for minting, burning, and querying License Tokens and their associated
/// metadata.
interface ILicenseToken is IERC721Metadata, IERC721Enumerable {
    /// @notice Metadata struct for License Tokens.
    /// @param licensorIpId The ID of the licensor IP for which the License Token was minted.
    /// @param licenseTemplate The address of the License Template associated with the License Token.
    /// @param licenseTermsId The ID of the License Terms associated with the License Token.
    /// @param transferable Whether the License Token is transferable, determined by the License Terms.
    struct LicenseTokenMetadata {
        address licensorIpId;
        address licenseTemplate;
        uint256 licenseTermsId;
        bool transferable;
        /// @custom:oz-renamed-from mintedAt
        uint256 deprecated_mintedAt;
        /// @custom:oz-renamed-from expiresAt
        uint256 deprecated_expiresAt;
    }

    /// @notice Emitted when a License Token is minted.
    /// @param minter The address of the minter of the License Token.
    /// The caller of mintLicenseTokens function of LicensingModule.
    /// @param receiver The address of the receiver of the License Token.
    /// @param tokenId The ID of the minted License Token.
    event LicenseTokenMinted(address indexed minter, address indexed receiver, uint256 indexed tokenId);

    /// @notice Mints a specified amount of License Tokens (LNFTs).
    /// @param licensorIpId The ID of the licensor IP for which the License Tokens are minted.
    /// @param licenseTemplate The address of the License Template.
    /// @param licenseTermsId The ID of the License Terms.
    /// @param amount The amount of License Tokens to mint.
    /// @param minter The address of the minter.
    /// @param receiver The address of the receiver of the minted License Tokens.
    /// @return startLicenseTokenId The start ID of the minted License Tokens.
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external returns (uint256 startLicenseTokenId);

    /// @notice Burns specified License Tokens.
    /// @param holder The address of the holder of the License Tokens.
    /// @param tokenIds An array of IDs of the License Tokens to be burned.
    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external;

    /// @notice Returns the total number of minted License Tokens since beginning,
    /// the number won't decrease when license tokens are burned.
    /// @return The total number of minted License Tokens.
    function totalMintedTokens() external view returns (uint256);

    /// @notice Returns the licensor IP ID associated with a given License Token.
    /// @param tokenId The ID of the License Token.
    /// @return The licensor IP ID associated with the License Token.
    function getLicensorIpId(uint256 tokenId) external view returns (address);

    /// @notice Returns the ID of the license terms that are used for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTermsId(uint256 tokenId) external view returns (uint256);

    /// @notice Returns the address of the license template that is used for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTemplate(uint256 tokenId) external view returns (address);

    /// @notice Checks if a License Token has been revoked.
    /// @param tokenId The ID of the License Token to check.
    /// @return True if the License Token has been revoked, false otherwise.
    function isLicenseTokenRevoked(uint256 tokenId) external view returns (bool);

    /// @notice Retrieves the metadata associated with a License Token.
    /// @param tokenId The ID of the License Token.
    /// @return A `LicenseTokenMetadata` struct containing the metadata of the specified License Token.
    function getLicenseTokenMetadata(uint256 tokenId) external view returns (LicenseTokenMetadata memory);

    /// @notice Validates License Tokens for registering a derivative IP.
    /// @dev This function checks if the License Tokens are valid for the derivative IP registration process.
    /// The function will be called by LicensingModule when registering a derivative IP with license tokens.
    /// @param childIpId The ID of the derivative IP.
    /// @param childIpOwner The address of the owner of the derivative IP.
    /// @param tokenIds An array of IDs of the License Tokens to validate for the derivative
    /// IP to register as derivative of the licensor IPs which minted the license tokens.
    /// @return licenseTemplate The address of the License Template associated with the License Tokens.
    /// @return licensorIpIds An array of licensor IPs associated with each License Token.
    /// @return licenseTermsIds An array of License Terms associated with each validated License Token.
    function validateLicenseTokensForDerivative(
        address childIpId,
        address childIpOwner,
        uint256[] calldata tokenIds
    ) external view returns (address licenseTemplate, address[] memory licensorIpIds, uint256[] memory licenseTermsIds);
}
