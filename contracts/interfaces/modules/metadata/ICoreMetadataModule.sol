// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IModule } from "../../../../contracts/interfaces/modules/base/IModule.sol";

/// @title CoreMetadataModule
/// @notice Manages the core metadata for IP assets within the Story Protocol.
/// @dev This contract allows setting and updating core metadata attributes for IP assets.
interface ICoreMetadataModule is IModule {
    /// @notice Emitted when the name for an IP asset is set.
    event IPNameSet(address indexed ipId, string name);

    /// @notice Emitted when the metadataURI for an IP asset is set.
    event MetadataURISet(address indexed ipId, string metadataURI);

    /// @notice Emitted when the content hash for an IP asset is set.
    event IPContentHashSet(address indexed ipId, bytes32 contentHash);

    /// @notice Sets the name for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param name The name to set for the IP asset.
    function setIpName(address ipAccount, string memory name) external;

    /// @notice Sets the metadataURI for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param metadataURI The metadataURI to set for the IP asset.
    function setMetadataURI(address ipAccount, string memory metadataURI) external;

    /// @notice Sets the content hash for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param contentHash The content hash to set for the IP asset.
    function setIpContentHash(address ipAccount, bytes32 contentHash) external;

    /// @notice Sets all core metadata for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param name The name to set for the IP asset.
    /// @param metadataURI The metadataURI to set for the IP asset.
    /// @param contentHash The content hash to set for the IP asset.
    function setAll(
        address ipAccount,
        string memory name,
        string memory metadataURI,
        bytes32 contentHash
    ) external;
}
