// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

interface IIPAccountStorage {
    function setString(bytes32 key, string calldata value) external;
    function getString(bytes32 key) external view returns (string memory);
    function getString(bytes32 namespace, bytes32 key) external view returns (string memory);

    function setBytes(bytes32 key, bytes calldata value) external;
    function getBytes(bytes32 key) external view returns (bytes memory);
    function getBytes(bytes32 namespace, bytes32 key) external view returns (bytes memory);

    function setBytes32(bytes32 key, bytes32 value) external;
    function getBytes32(bytes32 key) external view returns (bytes32);
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32);

    function setUint256(bytes32 key, uint256 value) external;
    function getUint256(bytes32 key) external view returns (uint256);
    function getUint256(bytes32 namespace, bytes32 key) external view returns (uint256);

    function setAddress(bytes32 key, address value) external;
    function getAddress(bytes32 key) external view returns (address);
    function getAddress(bytes32 namespace, bytes32 key) external view returns (address);

    function getBool(bytes32 key) external view returns (bool);
    function getBool(bytes32 namespace, bytes32 key) external view returns (bool);
    function setBool(bytes32 key, bool value) external;
}
