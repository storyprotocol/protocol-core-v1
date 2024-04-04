// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title ILicenseNFT
interface ILicenseNFT {
    struct LicenseTokenMetadata {
        address originalIpId;
        address licenseTemplate;
        uint256 licenseConfigId;
        bool transferable;
        uint256 mintedAt;
        uint256 expiresAt;
    }

    event LicenseTokenMinted(
        address indexed creator,
        address indexed receiver,
        uint256 indexed tokenId,
        LicenseTokenMetadata licenseTokenMetadata
    );

    function mintLicenseTokens(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseConfigId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external returns (uint256 startLicenseTokenId, uint256 endLicenseTokenId);

    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external;

    function totalMintedTokens() external view returns (uint256);

    function originalIpId(uint256 tokenId) external view returns (address);

    function isLicenseTokenRevoked(uint256 tokenId) external view returns (bool);

    function licenseTokenMetadata(uint256 tokenId) external view returns (LicenseTokenMetadata memory);

    function validateLicenseTokensForDerivative(
        address derivativeIpId,
        address derivativeIpOwner,
        uint256[] calldata tokenIds
    )
        external
        view
        returns (address licenseTemplate, address[] memory originalIpIds, uint256[] memory licenseConfigIds);
}
