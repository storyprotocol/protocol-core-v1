// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Library for working with Openzeppelin's ShortString data types.
library ShortStringOps {
    using ShortStrings for *;
    using Strings for *;

    /// @dev Compares whether two ShortStrings are equal.
    function equal(ShortString a, ShortString b) internal pure returns (bool) {
        return ShortString.unwrap(a) == ShortString.unwrap(b);
    }

    /// @dev Checks whether a ShortString and a regular string are equal.
    function equal(ShortString a, string memory b) internal pure returns (bool) {
        return equal(a, b.toShortString());
    }

    /// @dev Checks whether a regular string and a ShortString are equal.
    function equal(string memory a, ShortString b) internal pure returns (bool) {
        return equal(a.toShortString(), b);
    }

    /// @dev Checks whether a bytes32 object and ShortString are equal.
    function equal(bytes32 a, ShortString b) internal pure returns (bool) {
        return a == ShortString.unwrap(b);
    }

    /// @dev Checks whether a string and bytes32 object are equal.
    function equal(string memory a, bytes32 b) internal pure returns (bool) {
        return equal(a, ShortString.wrap(b));
    }

    /// @dev Checks whether a bytes32 object and string are equal.
    function equal(bytes32 a, string memory b) internal pure returns (bool) {
        return equal(ShortString.wrap(a), b);
    }

    function stringToBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }

    function bytes32ToString(bytes32 b) internal pure returns (string memory) {
        return ShortString.wrap(b).toString();
    }

    function toShortString(uint256 value) internal pure returns (ShortString) {
        return value.toString().toShortString();
    }
}
