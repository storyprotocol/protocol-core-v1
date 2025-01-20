// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IViewModule } from "../base/IViewModule.sol";

/// @title CoreMetadataViewModule
/// @notice This view module provides getter functions to access all core metadata
///         and generate json string of all core metadata returned by tokenURI().
///         The view module consolidates core metadata for IPAssets from both IPAssetRegistry and CoreMetadataModule.
/// @dev The "name" from CoreMetadataModule overrides the "name" from IPAssetRegistry if set.
interface ICoreMetadataViewModule is IViewModule {
    /// @notice Core metadata struct for IPAssets.
    struct CoreMetadata {
        string nftTokenURI;
        bytes32 nftMetadataHash;
        string metadataURI;
        bytes32 metadataHash;
        uint256 registrationDate;
        address owner;
    }

    /// @notice Retrieves the metadataURI of the IPAsset from CoreMetadataModule.
    /// @param ipId The address of the IPAsset.
    /// @return The metadataURI of the IPAsset.
    function getMetadataURI(address ipId) external view returns (string memory);

    /// @notice Retrieves the metadata hash of the IPAsset from CoreMetadataModule.
    /// @param ipId The address of the IPAsset.
    /// @return The metadata hash of the IPAsset.
    function getMetadataHash(address ipId) external view returns (bytes32);

    /// @notice Retrieves the registration date of the IPAsset from IPAssetRegistry.
    /// @param ipId The address of the IPAsset.
    /// @return The registration date of the IPAsset.
    function getRegistrationDate(address ipId) external view returns (uint256);

    /// @notice Retrieves the TokenURI of the NFT to which IP Asset bound.
    /// @param ipId The address of the IPAsset.
    /// @return The NFT TokenURI of the IPAsset.
    function getNftTokenURI(address ipId) external view returns (string memory);

    /// @notice Retrieves the metadata hash of the NFT to which IP Asset bound.
    /// @param ipId The address of the IPAsset.
    /// @return The NFT metadata hash of the IPAsset.
    function getNftMetadataHash(address ipId) external view returns (bytes32);

    /// @notice Retrieves the owner of the IPAsset.
    /// @param ipId The address of the IPAsset.
    /// @return The address of the owner of the IPAsset.
    function getOwner(address ipId) external view returns (address);

    /// @notice Retrieves all core metadata of the IPAsset.
    /// @param ipId The address of the IPAsset.
    /// @return The CoreMetadata struct of the IPAsset.
    function getCoreMetadata(address ipId) external view returns (CoreMetadata memory);

    /// @notice Generates a JSON string formatted according to the standard NFT metadata schema for the IPAsset,
    ///        including all relevant metadata fields.
    /// @dev This function consolidates metadata from both IPAssetRegistry
    ///      and CoreMetadataModule, with "name" from CoreMetadataModule taking precedence.
    /// @param ipId The address of the IPAsset.
    /// @return A JSON string representing all metadata of the IPAsset.
    function getJsonString(address ipId) external view returns (string memory);
}
