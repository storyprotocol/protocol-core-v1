// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title Access Permission Library
/// @notice Library for IPAccount access control permissions.
///         These permissions are used by the AccessController.
library AccessPermission {
    /// @notice ABSTAIN means having not enough information to make decision at current level, deferred decision to up
    /// level permission.
    uint8 public constant ABSTAIN = 0;

    /// @notice ALLOW means the permission is granted to transaction signer to call the function.
    uint8 public constant ALLOW = 1;

    /// @notice DENY means the permission is denied to transaction signer to call the function.
    uint8 public constant DENY = 2;

    /// @notice This struct is used to represent permissions in batch operations within the AccessController.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The permission level for the transaction (0 = ABSTAIN, 1 = ALLOW, 2 = DENY).
    struct Permission {
        address ipAccount;
        address signer;
        address to;
        bytes4 func;
        uint8 permission;
    }
}
