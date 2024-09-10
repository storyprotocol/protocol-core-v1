// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessPermission } from "../../lib/AccessPermission.sol";

interface IAccessController {
    /// @notice Emitted when a permission is set.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the IP account
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The permission level
    event PermissionSet(
        address ipAccountOwner,
        address indexed ipAccount,
        address indexed signer,
        address indexed to,
        bytes4 func,
        uint8 permission
    );

    /// @notice Sets a batch of permissions in a single transaction.
    /// @dev This function allows setting multiple permissions at once. Pausable.
    /// @param permissions An array of `Permission` structs, each representing the permission to be set.
    function setBatchPermissions(AccessPermission.Permission[] memory permissions) external;

    /// @notice Sets the permission for a specific function call
    /// @dev Each policy is represented as a mapping from an IP account address to a signer address to a recipient
    /// address to a function selector to a permission level. The permission level can be 0 (ABSTAIN), 1 (ALLOW), or
    /// 2 (DENY).
    /// @dev By default, all policies are set to 0 (ABSTAIN), which means that the permission is not set.
    /// The owner of ipAccount by default has all permission.
    /// address(0) => wildcard
    /// bytes4(0) => wildcard
    /// Specific permission overrides wildcard permission.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The new permission level
    function setPermission(address ipAccount, address signer, address to, bytes4 func, uint8 permission) external;

    /// @notice Sets permission to a signer for all functions across all modules.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`.
    /// @param signer The address of the signer receiving the permissions.
    /// @param permission The new permission.
    function setAllPermissions(address ipAccount, address signer, uint8 permission) external;

    /// @notice Checks the permission level for a specific function call. Reverts if permission is not granted.
    /// Otherwise, the function is a noop.
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    function checkPermission(address ipAccount, address signer, address to, bytes4 func) external view;

    /// @notice Returns the permission level for a specific function call.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @return permission The current permission level for the function call on `to` by the `signer` for `ipAccount`
    function getPermission(address ipAccount, address signer, address to, bytes4 func) external view returns (uint8);
}
