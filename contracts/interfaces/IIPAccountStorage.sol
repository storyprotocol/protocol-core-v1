// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title IPAccount Namespaced Storage Interface
/// @dev Provides a structured way to store IPAccount's state using a namespaced storage pattern.
/// This interface facilitates conflict-free data writing by different Modules into the same IPAccount
/// by utilizing namespaces.
/// The default namespace for write operations is determined by the `msg.sender`, ensuring that only the owning Module
/// (i.e., the Module calling the write functions) can write data into its respective namespace.
/// However, read operations are unrestricted and can access any namespace.
///
/// Rules:
/// - The default namespace for a Module is its own address.
/// - Every Module can read data from any namespace.
/// - Only the owning Module (i.e., the Module whose address is used as the namespace) can write data into
///   its respective namespace.
interface IIPAccountStorage is IERC165 {
    /// @dev Sets a bytes value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes value to be stored.
    function setBytes(bytes32 key, bytes calldata value) external;

    /// @notice Sets multiple `bytes` values for an array of keys within the namespace of the caller (`msg.sender`).
    /// @param keys An array of `bytes32` keys under which the `bytes` values will be stored.
    /// @param values An array of `bytes` values corresponding to the keys to be stored.
    /// @dev The function requires that the arrays `keys` and `values` have the same length.
    function setBytesBatch(bytes32[] calldata keys, bytes[] calldata values) external;

    /// @notice Retrieves an array of `bytes` values corresponding to an array of keys from specified namespaces.
    /// @param namespaces An array of `bytes32` representing the namespaces from which values are to be retrieved.
    /// @param keys An array of `bytes32` representing the keys corresponding to the values to be retrieved.
    /// @return values An array of `bytes` containing the values associated with the specified keys
    /// across the given namespaces.
    /// @dev Requires that the length of `namespaces` and `keys` arrays be the same to ensure correct data retrieval.
    function getBytesBatch(
        bytes32[] calldata namespaces,
        bytes32[] calldata keys
    ) external view returns (bytes[] memory values);

    /// @dev Retrieves a bytes value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes value stored under the specified key.
    function getBytes(bytes32 key) external view returns (bytes memory);

    /// @dev Retrieves a bytes value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(bytes32 namespace, bytes32 key) external view returns (bytes memory);

    /// @dev Sets a bytes32 value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes32 value to be stored.
    function setBytes32(bytes32 key, bytes32 value) external;

    /// @notice Sets an array of `bytes32` values for corresponding keys within the caller's (`msg.sender`) namespace.
    /// @param keys An array of `bytes32` keys under which the values will be stored.
    /// @param values An array of `bytes32` values to be stored under the specified keys.
    /// @dev The function requires that the `keys` and `values` arrays have the same length for correct mapping.
    function setBytes32Batch(bytes32[] calldata keys, bytes32[] calldata values) external;

    /// @notice Retrieves an array of `bytes32` values corresponding to specified keys across multiple namespaces.
    /// @param namespaces An array of `bytes32` representing the namespaces from which to retrieve the values.
    /// @param keys An array of `bytes32` keys for which values are to be retrieved.
    /// @return values An array of `bytes32` values retrieved from the specified keys within the given namespaces.
    /// @dev The `namespaces` and `keys` arrays must be the same length.
    function getBytes32Batch(
        bytes32[] calldata namespaces,
        bytes32[] calldata keys
    ) external view returns (bytes32[] memory values);

    /// @dev Retrieves a bytes32 value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key.
    function getBytes32(bytes32 key) external view returns (bytes32);

    /// @dev Retrieves a bytes32 value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32);
}
