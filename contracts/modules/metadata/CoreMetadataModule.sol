// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { BaseModule } from "../BaseModule.sol";
import { Errors } from "../../lib/Errors.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { CORE_METADATA_MODULE_KEY } from "../../lib/modules/Module.sol";
import { ICoreMetadataModule } from "../../interfaces/modules/metadata/ICoreMetadataModule.sol";

/// @title CoreMetadataModule
/// @notice Manages the core metadata for IP assets within the Story Protocol, all metadata can only update once.
/// @dev This contract allows setting core metadata attributes for IP assets.
///      It implements the ICoreMetadataModule interface.
contract CoreMetadataModule is BaseModule, AccessControlled, ICoreMetadataModule {
    using IPAccountStorageOps for IIPAccount;

    string public override name = CORE_METADATA_MODULE_KEY;

    /// @notice Modifier to ensure that metadata can only be set once.
    modifier onlyOnce(address ipAccount, bytes32 metadataName) {
        if (!_isEmptyString(IIPAccount(payable(ipAccount)).getString(metadataName))) {
            revert Errors.CoreMetadataModule__MetadataAlreadySet();
        }
        _;
    }

    /// @notice Creates a new CoreMetadataModule instance.
    /// @param accessController The address of the AccessController contract.
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract.
    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {}

    /// @notice Sets the name for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param name The name to set for the IP asset.
    function setIpName(address ipAccount, string memory ipName) external verifyPermission(ipAccount) {
        _setIpName(ipAccount, ipName);
    }

    /// @notice Sets the description for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param description The description to set for the IP asset.
    function setIpDescription(address ipAccount, string memory description) external verifyPermission(ipAccount) {
        _setIpDescription(ipAccount, description);
    }

    /// @notice Sets the content hash for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param contentHash The content hash to set for the IP asset.
    function setIpContentHash(address ipAccount, bytes32 contentHash) external verifyPermission(ipAccount) {
        _setIpContentHash(ipAccount, contentHash);
    }

    /// @notice Sets all core metadata for an IP asset.
    /// @dev Can only be called once per IP asset to prevent overwriting.
    /// @param ipAccount The address of the IP asset.
    /// @param name The name to set for the IP asset.
    /// @param description The description to set for the IP asset.
    /// @param contentHash The content hash to set for the IP asset.
    function setIpMetadata(
        address ipAccount,
        string memory ipName,
        string memory description,
        bytes32 contentHash
    ) external verifyPermission(ipAccount) {
        _setIpName(ipAccount, ipName);
        _setIpDescription(ipAccount, description);
        _setIpContentHash(ipAccount, contentHash);
    }

    /// @dev Implements the IERC165 interface.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ICoreMetadataModule).interfaceId || super.supportsInterface(interfaceId);
    }

    function _setIpName(address ipAccount, string memory ipName) internal onlyOnce(ipAccount, "IP_NAME") {
        IIPAccount(payable(ipAccount)).setString("IP_NAME", ipName);
        emit IPNameSet(ipAccount, ipName);
    }

    function _setIpDescription(
        address ipAccount,
        string memory description
    ) internal onlyOnce(ipAccount, "IP_DESCRIPTION") {
        IIPAccount(payable(ipAccount)).setString("IP_DESCRIPTION", description);
        emit IPDescriptionSet(ipAccount, description);
    }

    function _setIpContentHash(address ipAccount, bytes32 contentHash) internal {
        if (IIPAccount(payable(ipAccount)).getBytes32("IP_CONTENT_HASH") != bytes32(0)) {
            revert Errors.CoreMetadataModule__MetadataAlreadySet();
        }
        IIPAccount(payable(ipAccount)).setBytes32("IP_CONTENT_HASH", contentHash);
        emit IPContentHashSet(ipAccount, contentHash);
    }

    /// @dev Checks if a string is empty.
    function _isEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }
}
