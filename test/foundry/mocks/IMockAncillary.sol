// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Mock Ancillary Interface
interface IMockAncillary {
    function requestPrice(bytes32 identifier, uint256 time, bytes memory ancillaryData) external;

    function pushPrice(bytes32 identifier, uint256 time, bytes memory ancillaryData, int256 price) external;
}
