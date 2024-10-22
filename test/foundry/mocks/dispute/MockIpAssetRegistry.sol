// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

contract MockIpAssetRegistry {
    function isRegistered(address ipId) external view returns (bool) {
        return true;
    }
}
