// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @notice Library for validating URIs.
library URIChecker {
    /// @dev Checks if the URI contains double quotes.
    /// @param uri The URI string to validate.
    /// @return returns true if the URI contains at least one double quote, false otherwise.
    function containsDoubleQuote(string memory uri) internal pure returns (bool) {
        bytes memory uriBytes = bytes(uri);
        // solhint-disable-next-line quotes
        bytes1 doubleQuote = bytes('"')[0];

        for (uint256 i = 0; i < uriBytes.length; i++) {
            if (uriBytes[i] == doubleQuote) {
                return true;
            }
        }
        return false;
    }
}
