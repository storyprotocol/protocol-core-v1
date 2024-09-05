// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

library ExpiringOps {
    /// @dev Get the earliest expiration time from two expiration times
    /// @param currentEarliestExp The current earliest expiration time
    /// @param anotherExp Another expiration time
    function getEarliestExpirationTime(
        uint256 currentEarliestExp,
        uint256 anotherExp
    ) internal view returns (uint256 earliestExp) {
        earliestExp = currentEarliestExp;
        if (anotherExp > 0 && (anotherExp < earliestExp || earliestExp == 0)) earliestExp = anotherExp;
    }
}
