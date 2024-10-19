// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IOOV3 Callbacks Interface
interface IOOV3Callbacks {
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external;

    function assertionDisputedCallback(bytes32 assertionId) external;
}
