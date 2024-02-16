// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IIPAccountStorage } from "../interfaces/IIPAccountStorage.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

library IPAccountStorageOps {
    using ShortStrings for *;
    using Strings for *;

    function setString(IIPAccountStorage ipStorage, ShortString key, string memory value) internal {
        ipStorage.setString(toBytes32(key), value);
    }

    function getString(IIPAccountStorage ipStorage, ShortString key) internal view returns (string memory) {
        return ipStorage.getString(toBytes32(key));
    }

    function getString(
        IIPAccountStorage ipStorage,
        address namespace,
        bytes32 key
    ) internal view returns (string memory) {
        return ipStorage.getString(toBytes32(namespace), key);
    }

    function getString(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (string memory) {
        return ipStorage.getString(toBytes32(namespace), toBytes32(key));
    }

    function setAddress(IIPAccountStorage ipStorage, ShortString key, address value) internal {
        ipStorage.setAddress(toBytes32(key), value);
    }

    function getAddress(IIPAccountStorage ipStorage, ShortString key) internal view returns (address) {
        return ipStorage.getAddress(toBytes32(key));
    }

    function getAddress(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (address) {
        return ipStorage.getAddress(toBytes32(namespace), key);
    }

    function getAddress(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (address) {
        return ipStorage.getAddress(toBytes32(namespace), toBytes32(key));
    }

    function setUint256(IIPAccountStorage ipStorage, ShortString key, uint256 value) internal {
        ipStorage.setUint256(toBytes32(key), value);
    }

    function getUint256(IIPAccountStorage ipStorage, ShortString key) internal view returns (uint256) {
        return ipStorage.getUint256(toBytes32(key));
    }

    function getUint256(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (uint256) {
        return ipStorage.getUint256(toBytes32(namespace), key);
    }

    function getUint256(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (uint256) {
        return ipStorage.getUint256(toBytes32(namespace), toBytes32(key));
    }

    function setBool(IIPAccountStorage ipStorage, ShortString key, bool value) internal {
        ipStorage.setBool(toBytes32(key), value);
    }

    function getBool(IIPAccountStorage ipStorage, ShortString key) internal view returns (bool) {
        return ipStorage.getBool(toBytes32(key));
    }

    function getBool(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (bool) {
        return ipStorage.getBool(toBytes32(namespace), key);
    }

    function getBool(IIPAccountStorage ipStorage, address namespace, ShortString key) internal view returns (bool) {
        return ipStorage.getBool(toBytes32(namespace), toBytes32(key));
    }

    function setBytes(IIPAccountStorage ipStorage, ShortString key, bytes memory value) internal {
        ipStorage.setBytes(toBytes32(key), value);
    }

    function setBytes(IIPAccountStorage ipStorage, ShortString key1, ShortString key2, bytes memory value) internal {
        ipStorage.setBytes(toBytes32(string(abi.encodePacked(key1.toString(), key2.toString()))), value);
    }

    function getBytes(IIPAccountStorage ipStorage, ShortString key) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(key));
    }

    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        bytes32 key
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(namespace), key);
    }

    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(namespace), toBytes32(key));
    }

    function getBytes(
        IIPAccountStorage ipStorage,
        ShortString key1,
        ShortString key2
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(string(abi.encodePacked(key1.toString(), key2.toString()))));
    }

    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key,
        ShortString key2
    ) internal view returns (bytes memory) {
        return
            ipStorage.getBytes(
                toBytes32(namespace),
                toBytes32(string(abi.encodePacked(key.toString(), key2.toString())))
            );
    }

    function setBytes32(IIPAccountStorage ipStorage, ShortString key, bytes32 value) internal {
        ipStorage.setBytes32(toBytes32(key), value);
    }

    function getBytes32(IIPAccountStorage ipStorage, ShortString key) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(key));
    }

    function getBytes32(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(namespace), key);
    }

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
