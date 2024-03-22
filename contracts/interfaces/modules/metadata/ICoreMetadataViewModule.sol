// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IViewModule } from "../base/IViewModule.sol";

/// @title CoreMetadataViewModule
/// @notice This view module provides getter functions to access all core metadata
///         and generate json string of all core metadata returned by tokenURI().
///         The view module consolidates core metadata for IPAccounts from both IPAssetRegistry and CoreMetadataModule.
/// @dev The "name" from CoreMetadataModule overrides the "name" from IPAssetRegistry if set.
interface ICoreMetadataViewModule is IViewModule {
    /// @notice Retrieves the name of the IPAccount, preferring the name from CoreMetadataModule if available.
    /// @param ipId The address of the IPAccount.
    /// @return The name of the IPAccount.
    function getName(address ipId) external view returns (string memory);

    /// @notice Retrieves the description of the IPAccount from CoreMetadataModule.
    /// @param ipId The address of the IPAccount.
    /// @return The description of the IPAccount.
    function getDescription(address ipId) external view returns (string memory);

    /// @notice Retrieves the registration date of the IPAccount from IPAssetRegistry.
    /// @param ipId The address of the IPAccount.
    /// @return The registration date of the IPAccount.
    function getRegistrationDate(address ipId) external view returns (uint256);

    /// @notice Retrieves the content hash of the IPAccount from CoreMetadataModule.
    /// @param ipId The address of the IPAccount.
    /// @return The content hash of the IPAccount.
    function getContentHash(address ipId) external view returns (bytes32);

    /// @notice Retrieves the URI of the IPAccount from IPAssetRegistry.
    /// @param ipId The address of the IPAccount.
    /// @return The URI of the IPAccount.
    function getUri(address ipId) external view returns (string memory);

    /// @notice Retrieves the owner of the IPAccount.
    /// @param ipId The address of the IPAccount.
    /// @return The address of the owner of the IPAccount.
    function getOwner(address ipId) external view returns (address);

    /// @notice Generates a JSON string of all metadata for the IPAccount.
    /// @dev This function consolidates metadata from both IPAssetRegistry
    ///      and CoreMetadataModule, with "name" from CoreMetadataModule taking precedence.
    /// @param ipId The address of the IPAccount.
    /// @return A JSON string representing all metadata of the IPAccount.
    function tokenURI(address ipId) external view returns (string memory);
}
