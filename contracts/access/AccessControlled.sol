// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IAccessController } from "../interfaces/access/IAccessController.sol";
import { IPAccountChecker } from "../lib/registries/IPAccountChecker.sol";
import { IIPAccountRegistry } from "../interfaces/registries/IIPAccountRegistry.sol";
import { Errors } from "../lib/Errors.sol";

/// @title AccessControlled
/// @notice Provides a base contract for access control functionalities.
/// @dev This abstract contract implements basic access control mechanisms with an emphasis
/// on IP account verification and permission checks.
/// It is designed to be used as a base contract for other contracts that require access control.
/// It provides modifiers and functions to verify if the caller has the necessary permission
/// and is a registered IP account.
abstract contract AccessControlled {
    using IPAccountChecker for IIPAccountRegistry;

    /// @notice The IAccessController instance for permission checks.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAccessController public immutable ACCESS_CONTROLLER;
    /// @notice The IIPAccountRegistry instance for IP account verification.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IIPAccountRegistry public immutable IP_ACCOUNT_REGISTRY;

    /// @notice Verifies that the caller has the necessary permission for the given IPAccount.
    /// @dev Modifier that calls _verifyPermission to check if the provided IP account has the required permission.
    /// modules can use this modifier to check if the caller has the necessary permission.
    /// @param ipAccount The address of the IP account to verify.
    modifier verifyPermission(address ipAccount) {
        _verifyPermission(ipAccount);
        _;
    }

    /// @notice Ensures that the caller is a registered IP account.
    /// @dev Modifier that checks if the msg.sender is a registered IP account.
    /// modules can use this modifier to check if the caller is a registered IP account.
    /// so that enforce only registered IP Account can call the functions.
    modifier onlyIpAccount() {
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(msg.sender)) {
            revert Errors.AccessControlled__CallerIsNotIpAccount(msg.sender);
        }
        _;
    }

    /// @dev Constructor
    /// @param accessController The address of the AccessController contract.
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address accessController, address ipAccountRegistry) {
        if (accessController == address(0)) revert Errors.AccessControlled__ZeroAddress();
        if (ipAccountRegistry == address(0)) revert Errors.AccessControlled__ZeroAddress();
        ACCESS_CONTROLLER = IAccessController(accessController);
        IP_ACCOUNT_REGISTRY = IIPAccountRegistry(ipAccountRegistry);
    }

    /// @dev Internal function to verify if the caller (msg.sender) has the required permission to execute
    /// the function on provided ipAccount.
    /// @param ipAccount The address of the IP account to verify.
    function _verifyPermission(address ipAccount) internal view {
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(ipAccount)) {
            revert Errors.AccessControlled__NotIpAccount(ipAccount);
        }

        if (msg.sender != ipAccount) {
            // revert if the msg.sender does not have permission
            ACCESS_CONTROLLER.checkPermission(ipAccount, msg.sender, address(this), msg.sig);
        }
    }

    /// @dev Internal function to check if the caller (msg.sender) has the required permission to execute
    /// the function on provided ipAccount, returning a boolean.
    /// @param ipAccount The address of the IP account to check.
    /// @return bool Returns true if the caller has permission, false otherwise.
    function _hasPermission(address ipAccount) internal view returns (bool) {
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(ipAccount)) {
            return false;
        }

        if (msg.sender == ipAccount) {
            return true;
        }

        try ACCESS_CONTROLLER.checkPermission(ipAccount, msg.sender, address(this), msg.sig) {
            return true;
        } catch {
            return false;
        }
    }
}
