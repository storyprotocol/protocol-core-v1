// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IIPAccountStorage } from "./interfaces/IIPAccountStorage.sol";
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

    mapping(bytes32 => mapping(bytes32 => string)) public stringData;
    mapping(bytes32 => mapping(bytes32 => bytes)) public bytesData;
    mapping(bytes32 => mapping(bytes32 => bytes32)) public bytes32Data;
    mapping(bytes32 => mapping(bytes32 => uint256)) public uint256Data;
    mapping(bytes32 => mapping(bytes32 => address)) public addressData;
    mapping(bytes32 => mapping(bytes32 => bool)) public boolData;

    /// @inheritdoc IIPAccountStorage
    function setBytes(bytes32 key, bytes calldata value) external {
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
    function setBytes32(bytes32 key, bytes32 value) external {
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
