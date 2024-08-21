// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

/// @title ERC7201 Helper Script
/// @notice This script logs the boilerplate code for ERC7201 storage location and getter function, to
/// help developers implement the ERC7201 interface in their contracts.
/// Thanks Mikhail Vladimirov for bytes32 to hex string conversion functions.
/// https://stackoverflow.com/questions/67893318/solidity-how-to-represent-bytes32-as-string
contract ERC7201HelperScript is Script {
    
    string constant NAMESPACE = "story-protocol";
    string constant CONTRACT_NAME = "GroupingModule";

    function run() external {
        bytes memory erc7201Key = abi.encodePacked(NAMESPACE, ".", CONTRACT_NAME);
        bytes32 hash = keccak256(abi.encode(uint256(keccak256(erc7201Key)) - 1)) & ~bytes32(uint256(0xff));

        // Log natspec and storage structure
        console2.log(string(abi.encodePacked("/// @dev Storage structure for the ", CONTRACT_NAME)));
        console2.log(string(abi.encodePacked("/// @custom:storage-location erc7201:", erc7201Key)));
        console2.log(string(abi.encodePacked("struct ", CONTRACT_NAME, "Storage {")));
        console2.log("    // Write storage variables here...");
        console2.log(string(abi.encodePacked("}")));
        console2.log("");

        // Log ERC7201 comment and storage location
        console2.log(
            string(
                abi.encodePacked(
                    "// keccak256(abi.encode(uint256(keccak256(",
                    '"',
                    erc7201Key,
                    '"',
                    ")) - 1)) & ~bytes32(uint256(0xff));"
                )
            )
        );
        console2.log(
            string(
                abi.encodePacked(
                    "bytes32 private constant ",
                    CONTRACT_NAME,
                    "StorageLocation = ",
                    toHexString(hash),
                    ";"
                )
            )
        );
        console2.log("");

        // Log getter function
        console2.log(string(abi.encodePacked("/// @dev Returns the storage struct of ", CONTRACT_NAME, ".")));
        console2.log(
            string(
                abi.encodePacked(
                    "function _get",
                    CONTRACT_NAME,
                    "Storage() private pure returns (",
                    CONTRACT_NAME,
                    "Storage storage $) {"
                )
            )
        );
        console2.log(string(abi.encodePacked("    assembly {")));
        console2.log(string(abi.encodePacked("        $.slot := ", CONTRACT_NAME, "StorageLocation")));
        console2.log(string(abi.encodePacked("    }")));
        console2.log(string(abi.encodePacked("}")));
    }

    function toHex16(bytes16 data) internal pure returns (bytes32 result) {
        result =
            (bytes32(data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000) |
            ((bytes32(data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64);
        result =
            (result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000) |
            ((result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32);
        result =
            (result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000) |
            ((result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16);
        result =
            (result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000) |
            ((result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8);
        result =
            ((result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4) |
            ((result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8);
        result = bytes32(
            0x3030303030303030303030303030303030303030303030303030303030303030 +
                uint256(result) +
                (((uint256(result) + 0x0606060606060606060606060606060606060606060606060606060606060606) >> 4) &
                    0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) *
                39
        );
    }

    function toHexString(bytes32 data) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", toHex16(bytes16(data)), toHex16(bytes16(data << 128))));
    }
}
