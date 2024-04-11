// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title ProtocolAdmin
/// @dev This library provides roles and utils to configure protocol AccessManager
library ProtocolAdmin {
    /// @notice Protocol admin role, as it is used in AccessManager.
    /// Root admin role, grants all roles.
    uint64 public constant PROTOCOL_ADMIN_ROLE = type(uint64).min; // 0
    string public constant PROTOCOL_ADMIN_ROLE_LABEL = "PROTOCOL_ADMIN_ROLE";
    /// @notice Public role, as it is used in AccessManager
    uint64 public constant PUBLIC_ROLE = type(uint64).max; // 2**64-1
    /// @notice Upgrader role, as it is used in AccessManager
    uint64 public constant UPGRADER_ROLE = 1;
    string public constant UPGRADER_ROLE_LABEL = "UPGRADER_ROLE";
}
