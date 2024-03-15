// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

library ProtocolRoles {

    /// @notice Protocol admin role, can grant/revoke roles under it
    /// @dev Same as OZ AccessManager's ADMIN_ROLE
    uint64 public constant ADMIN = type(uint64).min; // 0
    /// @notice Upgrader role, can set new implementation for a proxy
    /// Role Admin: ADMIN
    uint64 public constant UPGRADER = 1;
    /// @notice Public role, has no special permissions
    /// @dev By default, everyone has this role in OZ AccessManager
    uint64 public constant PUBLIC = type(uint64).max; // 2**64-1

}