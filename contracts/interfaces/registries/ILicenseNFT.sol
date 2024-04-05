// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/// @title ILicenseNFT
/// @notice Interface for the License Token (ERC721) NFT collection that manages License Tokens representing
/// License Terms.
/// Each License Token may represent a set of License Terms and could have an expiration time.
/// License Tokens are ERC721 NFTs that can be minted, transferred (if allowed), and burned.
/// Derivative IP owners can burn License Tokens to register their IP as a derivative of the original IP for which
/// the License Token was minted.
/// This interface includes functionalities for minting, burning, and querying License Tokens and their associated
/// metadata.
interface ILicenseNFT is IERC721Metadata, IERC721Enumerable {
    /// @notice Metadata struct for License Tokens.
    /// @param originalIpId The ID of the original IP for which the License Token was minted.
    /// @param licenseTemplate The address of the License Template associated with the License Token.
    /// @param licenseTermsId The ID of the License Terms associated with the License Token.
    /// @param transferable Whether the License Token is transferable, determined by the License Terms.
    /// @param mintedAt The timestamp at which the License Token was minted.
    /// @param expiresAt The timestamp at which the License Token expires.
    struct LicenseTokenMetadata {
        address originalIpId;
        address licenseTemplate;
        uint256 licenseTermsId;
        bool transferable;
        uint256 mintedAt;
        uint256 expiresAt;
    }

    /// @notice Emitted when a License Token is minted.
    /// @param creator The address of the creator of the License Token.
    /// The caller of mintLicenseTokens function of LicensingModule.
    /// @param receiver The address of the receiver of the License Token.
    /// @param tokenId The ID of the minted License Token.
    /// @param licenseTokenMetadata The metadata of the minted License Token.
    event LicenseTokenMinted(
        address indexed creator,
        address indexed receiver,
        uint256 indexed tokenId,
        LicenseTokenMetadata licenseTokenMetadata
    );

    /// @notice Mints a specified amount of License Tokens (LNFTs).
    /// @param originalIpId The ID of the original IP for which the License Tokens are minted.
    /// @param licenseTemplate The address of the License Template.
    /// @param licenseTermsId The ID of the License Terms.
    /// @param amount The amount of License Tokens to mint.
    /// @param minter The address of the minter.
    /// @param receiver The address of the receiver of the minted License Tokens.
    /// @return startLicenseTokenId The start ID of the minted License Tokens.
    /// @return endLicenseTokenId The end ID of the minted License Tokens.
    function mintLicenseTokens(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external returns (uint256 startLicenseTokenId, uint256 endLicenseTokenId);

    /// @notice Burns specified License Tokens.
    /// @param holder The address of the holder of the License Tokens.
    /// @param tokenIds An array of IDs of the License Tokens to be burned.
    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external;

    /// @notice Returns the total number of minted License Tokens since beginning,
    /// the number won't decrease when license tokens are burned.
    /// @return The total number of minted License Tokens.
    function totalMintedTokens() external view returns (uint256);

    /// @notice Returns the original IP ID associated with a given License Token.
    /// @param tokenId The ID of the License Token.
    /// @return The original IP ID associated with the License Token.
    function originalIpId(uint256 tokenId) external view returns (address);

    /// @notice Checks if a License Token has been revoked.
    /// @param tokenId The ID of the License Token to check.
    /// @return True if the License Token has been revoked, false otherwise.
    function isLicenseTokenRevoked(uint256 tokenId) external view returns (bool);

    /// @notice Retrieves the metadata associated with a License Token.
    /// @param tokenId The ID of the License Token.
    /// @return A `LicenseTokenMetadata` struct containing the metadata of the specified License Token.
    function licenseTokenMetadata(uint256 tokenId) external view returns (LicenseTokenMetadata memory);

    /// @notice Validates License Tokens for registering a derivative IP.
    /// @dev This function checks if the License Tokens are valid for the derivative IP registration process.
    /// for example, whether token is expired.
    /// The function will be called by LicensingModule when registering a derivative IP with license tokens.
    /// @param derivativeIpId The ID of the derivative IP.
    /// @param derivativeIpOwner The address of the owner of the derivative IP.
    /// @param tokenIds An array of IDs of the License Tokens to validate for the derivative
    /// IP to register as derivative of the original IPs which minted the license tokens.
    /// @return licenseTemplate The address of the License Template associated with the License Tokens.
    /// @return originalIpIds An array of original IPs associated with each License Token.
    /// @return licenseTermsIds An array of License Terms associated with each validated License Token.
    function validateLicenseTokensForDerivative(
        address derivativeIpId,
        address derivativeIpOwner,
        uint256[] calldata tokenIds
    ) external view returns (address licenseTemplate, address[] memory originalIpIds, uint256[] memory licenseTermsIds);
}
