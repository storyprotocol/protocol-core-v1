// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IIPAccountStorage } from "./interfaces/IIPAccountStorage.sol";
import { IModuleRegistry } from "./interfaces/registries/IModuleRegistry.sol";
import { Errors } from "./lib/Errors.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
/// @title IPAccount Storage
/// @dev Implements the IIPAccountStorage interface for managing IPAccount's state using a namespaced storage pattern.
/// Inherits all functionalities from IIPAccountStorage, providing concrete implementations for the interface's methods.
/// This contract allows Modules to store and retrieve data in a structured and conflict-free manner
/// by utilizing namespaces, where the default namespace is determined by the
/// `msg.sender` (the caller Module's address).
/// This impl is not part of an upgradeable proxy/impl setup. We are
/// adding OZ annotations to avoid false positives when running oz-foundry-upgrades
contract IPAccountStorage is ERC165, IIPAccountStorage {
    using ShortStrings for *;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable MODULE_REGISTRY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable LICENSE_REGISTRY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address ipAssetRegistry, address licenseRegistry, address moduleRegistry) {
        if (ipAssetRegistry == address(0)) revert Errors.IPAccountStorage__ZeroIpAssetRegistry();
        if (licenseRegistry == address(0)) revert Errors.IPAccountStorage__ZeroLicenseRegistry();
        if (moduleRegistry == address(0)) revert Errors.IPAccountStorage__ZeroModuleRegistry();
        MODULE_REGISTRY = moduleRegistry;
        LICENSE_REGISTRY = licenseRegistry;
        IP_ASSET_REGISTRY = ipAssetRegistry;
    }

    /// @dev Sets a bytes value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes value to be stored.
    function setBytes(bytes32 key, bytes calldata value) external onlyRegisteredModule {
        bytesData[_toBytes32(msg.sender)][key] = value;
    }

    /// @notice Sets multiple `bytes` values for an array of keys within the namespace of the caller (`msg.sender`).
    /// @param keys An array of `bytes32` keys under which the `bytes` values will be stored.
    /// @param values An array of `bytes` values corresponding to the keys to be stored.
    /// @dev The function requires that the arrays `keys` and `values` have the same length.
    function setBytesBatch(bytes32[] calldata keys, bytes[] calldata values) external onlyRegisteredModule {
        if (keys.length != values.length) revert Errors.IPAccountStorage__InvalidBatchLengths();
        for (uint256 i = 0; i < keys.length; i++) {
            bytesData[_toBytes32(msg.sender)][keys[i]] = values[i];
        }
    }

    /// @notice Retrieves an array of `bytes` values corresponding to an array of keys from specified namespaces.
    /// @param namespaces An array of `bytes32` representing the namespaces from which values are to be retrieved.
    /// @param keys An array of `bytes32` representing the keys corresponding to the values to be retrieved.
    /// @return values An array of `bytes` containing the values associated with the specified keys
    /// across the given namespaces.
    /// @dev Requires that the length of `namespaces` and `keys` arrays be the same to ensure correct data retrieval.
    function getBytesBatch(
        bytes32[] calldata namespaces,
        bytes32[] calldata keys
    ) external view returns (bytes[] memory values) {
        if (namespaces.length != keys.length) revert Errors.IPAccountStorage__InvalidBatchLengths();
        values = new bytes[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = bytesData[namespaces[i]][keys[i]];
        }
    }

    /// @dev Retrieves a bytes value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes value stored under the specified key.
    function getBytes(bytes32 key) external view returns (bytes memory) {
        return bytesData[_toBytes32(msg.sender)][key];
    }

    /// @dev Retrieves a bytes value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(bytes32 namespace, bytes32 key) external view returns (bytes memory) {
        return bytesData[namespace][key];
    }

    /// @dev Sets a bytes32 value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes32 value to be stored.
    function setBytes32(bytes32 key, bytes32 value) external onlyRegisteredModule {
        bytes32Data[_toBytes32(msg.sender)][key] = value;
    }

    /// @notice Sets an array of `bytes32` values for corresponding keys within the caller's (`msg.sender`) namespace.
    /// @param keys An array of `bytes32` keys under which the values will be stored.
    /// @param values An array of `bytes32` values to be stored under the specified keys.
    /// @dev The function requires that the `keys` and `values` arrays have the same length for correct mapping.
    function setBytes32Batch(bytes32[] calldata keys, bytes32[] calldata values) external onlyRegisteredModule {
        if (keys.length != values.length) revert Errors.IPAccountStorage__InvalidBatchLengths();
        for (uint256 i = 0; i < keys.length; i++) {
            bytes32Data[_toBytes32(msg.sender)][keys[i]] = values[i];
        }
    }

    /// @notice Retrieves an array of `bytes32` values corresponding to specified keys across multiple namespaces.
    /// @param namespaces An array of `bytes32` representing the namespaces from which to retrieve the values.
    /// @param keys An array of `bytes32` keys for which values are to be retrieved.
    /// @return values An array of `bytes32` values retrieved from the specified keys within the given namespaces.
    /// @dev The `namespaces` and `keys` arrays must be the same length.
    function getBytes32Batch(
        bytes32[] calldata namespaces,
        bytes32[] calldata keys
    ) external view returns (bytes32[] memory values) {
        if (namespaces.length != keys.length) revert Errors.IPAccountStorage__InvalidBatchLengths();
        values = new bytes32[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = bytes32Data[namespaces[i]][keys[i]];
        }
    }

    /// @dev Retrieves a bytes32 value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key.
    function getBytes32(bytes32 key) external view returns (bytes32) {
        return bytes32Data[_toBytes32(msg.sender)][key];
    }

    /// @dev Retrieves a bytes32 value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32) {
        return bytes32Data[namespace][key];
    }

    /// @notice ERC165 interface identifier for IIPAccountStorage
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IIPAccountStorage).interfaceId || super.supportsInterface(interfaceId);
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
