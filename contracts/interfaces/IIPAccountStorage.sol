// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

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
interface IIPAccountStorage {
    /// @dev Sets a string value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The string value to be stored.
    function setString(bytes32 key, string calldata value) external;

    /// @dev Retrieves a string value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The string value stored under the specified key.
    function getString(bytes32 key) external view returns (string memory);

    /// @dev Retrieves a string value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The string value stored under the specified key in the given namespace.
    function getString(bytes32 namespace, bytes32 key) external view returns (string memory);

    /// @dev Sets a bytes value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes value to be stored.
    function setBytes(bytes32 key, bytes calldata value) external;

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

    /// @dev Retrieves a bytes32 value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key.
    function getBytes32(bytes32 key) external view returns (bytes32);

    /// @dev Retrieves a bytes32 value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32);

    /// @dev Sets a uint256 value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The uint256 value to be stored.
    function setUint256(bytes32 key, uint256 value) external;

    /// @dev Retrieves a uint256 value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The uint256 value stored under the specified key.
    function getUint256(bytes32 key) external view returns (uint256);

    /// @dev Retrieves a uint256 value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(bytes32 namespace, bytes32 key) external view returns (uint256);

    /// @dev Sets an address value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The address value to be stored.
    function setAddress(bytes32 key, address value) external;

    /// @dev Retrieves an address value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The address value stored under the specified key.
    function getAddress(bytes32 key) external view returns (address);

    /// @dev Retrieves an address value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(bytes32 namespace, bytes32 key) external view returns (address);

    /// @dev Sets a boolean value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The boolean value to be stored.
    function getBool(bytes32 key) external view returns (bool);

    /// @dev Retrieves a boolean value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The boolean value stored under the specified key.
    function getBool(bytes32 namespace, bytes32 key) external view returns (bool);

    /// @dev Retrieves a boolean value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The boolean value stored under the specified key in the given namespace.
    function setBool(bytes32 key, bool value) external;
}
