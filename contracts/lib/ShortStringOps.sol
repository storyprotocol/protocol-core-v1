// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Library for working with Openzeppelin's ShortString data types.
library ShortStringOps {
    using ShortStrings for *;
    using Strings for *;

    /// @dev Convert string to bytes32 using ShortString
    function stringToBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }
}
