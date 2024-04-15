// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IIPAccountStorage } from "./interfaces/IIPAccountStorage.sol";
import { IModuleRegistry } from "./interfaces/registries/IModuleRegistry.sol";
import { Errors } from "./lib/Errors.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
/// @title IPAccount Storage
/// @dev Implements the IIPAccountStorage interface for managing IPAccount's state using a namespaced storage pattern.
/// Inherits all functionalities from IIPAccountStorage, providing concrete implementations for the interface's methods.
/// This contract allows Modules to store and retrieve data in a structured and conflict-free manner
/// by utilizing namespaces, where the default namespace is determined by the
/// `msg.sender` (the caller Module's address).
contract IPAccountStorage is ERC165, IIPAccountStorage {
    using ShortStrings for *;

    address public immutable MODULE_REGISTRY;
    address public immutable LICENSE_REGISTRY;
    address public immutable IP_ASSET_REGISTRY;

    mapping(bytes32 => mapping(bytes32 => bytes)) public bytesData;
    mapping(bytes32 => mapping(bytes32 => bytes32)) public bytes32Data;

    modifier onlyRegisteredModule() {
        if (
            msg.sender != IP_ASSET_REGISTRY &&
            msg.sender != LICENSE_REGISTRY &&
            !IModuleRegistry(MODULE_REGISTRY).isRegistered(msg.sender)
        ) {
            revert Errors.IPAccountStorage__NotRegisteredModule(msg.sender);
        }
        _;
    }

    constructor(address ipAssetRegistry, address licenseRegistry, address moduleRegistry) {
        MODULE_REGISTRY = moduleRegistry;
        LICENSE_REGISTRY = licenseRegistry;
        IP_ASSET_REGISTRY = ipAssetRegistry;
    }

    /// @inheritdoc IIPAccountStorage
    function setBytes(bytes32 key, bytes calldata value) external onlyRegisteredModule {
        bytesData[_toBytes32(msg.sender)][key] = value;
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes(bytes32 key) external view returns (bytes memory) {
        return bytesData[_toBytes32(msg.sender)][key];
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes(bytes32 namespace, bytes32 key) external view returns (bytes memory) {
        return bytesData[namespace][key];
    }

    /// @inheritdoc IIPAccountStorage
    function setBytes32(bytes32 key, bytes32 value) external onlyRegisteredModule {
        bytes32Data[_toBytes32(msg.sender)][key] = value;
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes32(bytes32 key) external view returns (bytes32) {
        return bytes32Data[_toBytes32(msg.sender)][key];
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32) {
        return bytes32Data[namespace][key];
    }

    /// @notice ERC165 interface identifier for IIPAccountStorage
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IIPAccountStorage).interfaceId || super.supportsInterface(interfaceId);
    }

    function _toBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
