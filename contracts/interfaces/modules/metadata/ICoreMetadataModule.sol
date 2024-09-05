// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "../../../../contracts/interfaces/modules/base/IModule.sol";

/// @title CoreMetadataModule
/// @notice Manages the core metadata for IP assets within the Story Protocol.
/// @dev This contract allows setting and updating core metadata attributes for IP assets.
interface ICoreMetadataModule is IModule {
    /// @notice Emitted when the nftTokenURI for an IP asset is set.
    event NFTTokenURISet(address indexed ipId, string nftTokenURI, bytes32 nftMetadataHash);

    /// @notice Emitted when the metadataURI for an IP asset is set.
    event MetadataURISet(address indexed ipId, string metadataURI, bytes32 metadataHash);

    /// @notice Emitted when all metadata for an IP asset are frozen.
    event MetadataFrozen(address indexed ipId);

    /// @notice Update the nftTokenURI for an IP asset,
    /// by retrieve the latest TokenURI from IP NFT to which the IP Asset bound.
    /// @dev Will revert if IP asset's metadata is frozen.
    /// @param ipId The address of the IP asset.
    /// @param nftMetadataHash A bytes32 hash representing the metadata of the NFT.
    /// This metadata is associated with the IP Asset and is accessible via the NFT's TokenURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    function updateNftTokenURI(address ipId, bytes32 nftMetadataHash) external;

    /// @notice Sets the metadataURI for an IP asset.
    /// @dev Will revert if IP asset's metadata is frozen.
    /// @param ipId The address of the IP asset.
    /// @param metadataURI The metadataURI to set for the IP asset.
    /// @param metadataHash The hash of metadata at metadataURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    function setMetadataURI(address ipId, string memory metadataURI, bytes32 metadataHash) external;

    /// @notice Sets all core metadata for an IP asset.
    /// @dev Will revert if IP asset's metadata is frozen.
    /// @param ipId The address of the IP asset.
    /// @param metadataURI The metadataURI to set for the IP asset.
    /// @param metadataHash The hash of metadata at metadataURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    /// @param nftMetadataHash A bytes32 hash representing the metadata of the NFT.
    /// This metadata is associated with the IP Asset and is accessible via the NFT's TokenURI.
    /// Use bytes32(0) to indicate that the metadata is not available.
    function setAll(address ipId, string memory metadataURI, bytes32 metadataHash, bytes32 nftMetadataHash) external;

    /// @notice make all metadata of the IP Asset immutable.
    /// @param ipId The address of the IP asset.
    function freezeMetadata(address ipId) external;

    /// @notice Check if the metadata of the IP Asset is immutable.
    /// @param ipId The address of the IP asset.
    function isMetadataFrozen(address ipId) external view returns (bool);
}
