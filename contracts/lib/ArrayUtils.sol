// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Address Array Utils
/// @notice Library for address array operations
library ArrayUtils {
    /// @notice Finds the index of the first occurrence of the given element.
    /// @param array The input array to search
    /// @param element The value to find
    /// @return Returns (index and isIn) for the first occurrence starting from index 0
    function indexOf(address[] memory array, address element) internal pure returns (uint32, bool) {
        for (uint32 i = 0; i < array.length; i++) {
            if (array[i] == element) return (i, true);
        }
        return (0, false);
    }
}
