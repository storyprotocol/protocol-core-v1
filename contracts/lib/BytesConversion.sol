// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Bytes Conversion
/// @notice Library for bytes conversion operations
library BytesConversion {
    /// @notice Converts a uint into a base-10, UTF-8 representation stored in a `string` type
    function toUtf8BytesUint(uint256 x) internal pure returns (bytes memory) {
        if (x == 0) {
            return "0";
        }
        uint256 j = x;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (x != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(x - (x / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            x /= 10;
        }
        return bstr;
    }
}
