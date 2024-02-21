// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IIPAccountStorage } from "../interfaces/IIPAccountStorage.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
/// @title IPAccount Storage Operations Library
/// @notice Provides utility functions that extend the basic functionalities of IPAccountStorage,
/// facilitating enhanced module interaction with IPAccount Namespaced Storage.
/// @dev This library enables modules to access and manipulate IPAccount Namespaced Storage
/// with additional features such as using `address` type namespaces and `ShortString` keys.
/// It serves as an addon to the fundamental IPAccountStorage functions, allowing for more complex and
/// flexible interactions with the namespaced storage.
library IPAccountStorageOps {
    using ShortStrings for *;
    using Strings for *;

    /// @dev Sets a string value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The string value to be stored.
    function setString(IIPAccountStorage ipStorage, bytes32 key, string memory value) internal {
        ipStorage.setBytes(key, bytes(value));
    }

    /// @dev Retrieves a string value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The string value stored under the specified key.
    function getString(IIPAccountStorage ipStorage, bytes32 key) internal view returns (string memory) {
        return string(ipStorage.getBytes(key));
    }

    /// @dev Retrieves a string value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The string value stored under the specified key in the given namespace.
    function getString(
        IIPAccountStorage ipStorage,
        bytes32 namespace,
        bytes32 key
    ) internal view returns (string memory) {
        return string(ipStorage.getBytes(namespace, key));
    }

    /// @notice Sets a string value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the value.
    /// @param value The string value to be stored.
    function setString(IIPAccountStorage ipStorage, ShortString key, string memory value) internal {
        setString(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves a string value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose value is to be retrieved.
    /// @return The string value stored under the specified key.
    function getString(IIPAccountStorage ipStorage, ShortString key) internal view returns (string memory) {
        return getString(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves a string value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the string value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose value is to be retrieved.
    function getString(
        IIPAccountStorage ipStorage,
        address namespace,
        bytes32 key
    ) internal view returns (string memory) {
        return getString(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves a string value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the string value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose value is to be retrieved.
    function getString(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (string memory) {
        return getString(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @dev Sets an address value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The address value to be stored.
    function setAddress(IIPAccountStorage ipStorage, bytes32 key, address value) internal {
        ipStorage.setBytes32(key, toBytes32(value));
    }

    /// @dev Retrieves an address value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The address value stored under the specified key.
    function getAddress(IIPAccountStorage ipStorage, bytes32 key) internal view returns (address) {
        return address(uint160(uint256(ipStorage.getBytes32(key))));
    }

    /// @dev Retrieves an address value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(IIPAccountStorage ipStorage, bytes32 namespace, bytes32 key) internal view returns (address) {
        return address(uint160(uint256(ipStorage.getBytes32(namespace, key))));
    }

    /// @notice Sets an address value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating address storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the address value.
    /// @param value The address value to be stored.
    function setAddress(IIPAccountStorage ipStorage, ShortString key, address value) internal {
        setAddress(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves an address value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the address data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose address value is to be retrieved.
    /// @return The address value stored under the specified key.
    function getAddress(IIPAccountStorage ipStorage, ShortString key) internal view returns (address) {
        return getAddress(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves an address value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the address value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose address value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (address) {
        return getAddress(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves an address value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the address value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose address value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (address) {
        return getAddress(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @dev Sets a uint256 value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The uint256 value to be stored.
    function setUint256(IIPAccountStorage ipStorage, bytes32 key, uint256 value) internal {
        ipStorage.setBytes32(key, bytes32(value));
    }

    /// @dev Retrieves a uint256 value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The uint256 value stored under the specified key.
    function getUint256(IIPAccountStorage ipStorage, bytes32 key) internal view returns (uint256) {
        return uint256(ipStorage.getBytes32(key));
    }

    /// @dev Retrieves a uint256 value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(IIPAccountStorage ipStorage, bytes32 namespace, bytes32 key) internal view returns (uint256) {
        return uint256(ipStorage.getBytes32(namespace, key));
    }

    /// @notice Sets a uint256 value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating uint256 storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the uint256 value.
    /// @param value The uint256 value to be stored.
    function setUint256(IIPAccountStorage ipStorage, ShortString key, uint256 value) internal {
        setUint256(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves a uint256 value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the uint256 data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose uint256 value is to be retrieved.
    /// @return The uint256 value stored under the specified key.
    function getUint256(IIPAccountStorage ipStorage, ShortString key) internal view returns (uint256) {
        return getUint256(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves a uint256 value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the uint256 value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose uint256 value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (uint256) {
        return getUint256(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves a uint256 value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the uint256 value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose uint256 value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (uint256) {
        return getUint256(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @dev Sets a boolean value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The boolean value to be stored.
    function setBool(IIPAccountStorage ipStorage, bytes32 key, bool value) internal {
        ipStorage.setBytes32(key, value ? bytes32(uint256(1)) : bytes32(0));
    }

    /// @dev Retrieves a boolean value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The boolean value stored under the specified key.
    function getBool(IIPAccountStorage ipStorage, bytes32 key) internal view returns (bool) {
        return ipStorage.getBytes32(key) != 0;
    }

    /// @dev Retrieves a boolean value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The boolean value stored under the specified key in the given namespace.
    function getBool(IIPAccountStorage ipStorage, bytes32 namespace, bytes32 key) internal view returns (bool) {
        return ipStorage.getBytes32(namespace, key) != 0;
    }

    /// @notice Sets a bool value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating bool storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the bool value.
    /// @param value The bool value to be stored.
    function setBool(IIPAccountStorage ipStorage, ShortString key, bool value) internal {
        setBool(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves a bool value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the bool data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose bool value is to be retrieved.
    /// @return The bool value stored under the specified key.
    function getBool(IIPAccountStorage ipStorage, ShortString key) internal view returns (bool) {
        return getBool(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves a bool value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the bool value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose bool value is to be retrieved.
    /// @return The bool value stored under the specified key in the given namespace.
    function getBool(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (bool) {
        return getBool(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves a bool value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the bool value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose bool value is to be retrieved.
    /// @return The bool value stored under the specified key in the given namespace.
    function getBool(IIPAccountStorage ipStorage, address namespace, ShortString key) internal view returns (bool) {
        return getBool(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @notice Sets a bytes value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating bytes storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the bytes value.
    /// @param value The bytes value to be stored.
    function setBytes(IIPAccountStorage ipStorage, ShortString key, bytes memory value) internal {
        ipStorage.setBytes(toBytes32(key), value);
    }

    /// @notice Sets a bytes value in the storage using two `ShortString` keys.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    function setBytes(IIPAccountStorage ipStorage, ShortString key1, ShortString key2, bytes memory value) internal {
        ipStorage.setBytes(toBytes32(string(abi.encodePacked(key1.toString(), key2.toString()))), value);
    }

    /// @notice Retrieves a bytes value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the bytes data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose bytes value is to be retrieved.
    /// @return The bytes value stored under the specified key.
    function getBytes(IIPAccountStorage ipStorage, ShortString key) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(key));
    }

    /// @notice Retrieves a bytes value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the bytes value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose bytes value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        bytes32 key
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(namespace), key);
    }

    /// @notice Retrieves a bytes value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the bytes value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose bytes value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(namespace), toBytes32(key));
    }

    /// @notice Retrieves a bytes value from the storage using two `ShortString` keys.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @return The bytes value stored under the combination of two keys.
    function getBytes(
        IIPAccountStorage ipStorage,
        ShortString key1,
        ShortString key2
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(string(abi.encodePacked(key1.toString(), key2.toString()))));
    }

    /// @notice Retrieves a bytes value from the storage under a specified namespace using two `ShortString` keys.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @return The bytes value stored under the combination of two keys.
    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key1,
        ShortString key2
    ) internal view returns (bytes memory) {
        return
            ipStorage.getBytes(
                toBytes32(namespace),
                toBytes32(string(abi.encodePacked(key1.toString(), key2.toString())))
            );
    }

    /// @notice Sets a bytes32 value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating bytes32 storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the bytes32 value.
    /// @param value The bytes32 value to be stored.
    function setBytes32(IIPAccountStorage ipStorage, ShortString key, bytes32 value) internal {
        ipStorage.setBytes32(toBytes32(key), value);
    }

    /// @notice Retrieves a bytes32 value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the bytes32 data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose bytes32 value is to be retrieved.
    /// @return The bytes32 value stored under the specified key.
    function getBytes32(IIPAccountStorage ipStorage, ShortString key) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(key));
    }

    /// @notice Retrieves a bytes32 value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the bytes32 value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose bytes32 value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(namespace), key);
    }

    /// @notice Retrieves a bytes32 value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the bytes32 value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose bytes32 value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(namespace), toBytes32(key));
    }

    function toBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }

    function toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function toBytes32(ShortString sstr) internal pure returns (bytes32) {
        // remove the length byte from the ShortString
        // so that bytes32 result is identical with converting string to bytes32 directly
        return ShortString.unwrap(sstr) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
    }
}
