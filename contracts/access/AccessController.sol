// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { IAccessController } from "../interfaces/access/IAccessController.sol";
import { IModuleRegistry } from "../interfaces/registries/IModuleRegistry.sol";
import { IIPAccountRegistry } from "../interfaces/registries/IIPAccountRegistry.sol";
import { IModuleRegistry } from "../interfaces/registries/IModuleRegistry.sol";
import { IPAccountChecker } from "../lib/registries/IPAccountChecker.sol";
import { IIPAccount } from "../interfaces/IIPAccount.sol";
import { AccessPermission } from "../lib/AccessPermission.sol";
import { Errors } from "../lib/Errors.sol";

/// @title AccessController
/// @dev This contract is used to control access permissions for different function calls in the protocol.
/// It allows setting permissions for specific function calls, checking permissions, and initializing the contract.
/// The contract uses a mapping to store policies, which are represented as a nested mapping structure.
/// The contract also interacts with other contracts such as IIPAccountRegistry, IModuleRegistry, and IIPAccount.
///
/// Each policy is represented as a mapping from an IP account address to a signer address to a recipient
/// address to a function selector to a permission level.
/// The permission level can be 0 (ABSTAIN), 1 (ALLOW), or 2 (DENY).
///
/// The contract includes the following functions:
/// - initialize: Sets the addresses of the IP account registry and the module registry.
/// - setPermission: Sets the permission for a specific function call.
/// - getPermission: Returns the permission level for a specific function call.
/// - checkPermission: Checks if a specific function call is allowed.
contract AccessController is IAccessController, AccessManagedUpgradeable, UUPSUpgradeable {
    using IPAccountChecker for IIPAccountRegistry;

    /// @dev The storage struct of AccessController.
    /// @param encodedPermissions tracks the permission granted to an encoded permission path, where the
    /// encoded permission path = keccak256(abi.encodePacked(ipAccount, signer, to, func))
    /// @notice The address of the IP Account Registry.
    /// @notice The address of the Module Registry.
    /// @custom:storage-location erc7201:story-protocol.AccessController
    struct AccessControllerStorage {
        mapping(bytes32 => uint8) encodedPermissions;
        address ipAccountRegistry;
        address moduleRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.AccessController")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant AccessControllerStorageLocation =
        0xe80df7f3a04d1e1a0b61a4a820184d4b4a2f8a6a808f315dbcc7b502f40b1800;

    /// Constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) {
            revert Errors.AccessController__ZeroAccessManager();
        }
        __AccessManaged_init(accessManager);
    }

    /// @notice Sets the addresses of the IP account registry and the module registry
    /// @dev TODO: figure out how to set these addresses in the constructor to make them immutable
    /// @param ipAccountRegistry address of the IP account registry
    /// @param moduleRegistry address of the module registry
    function setAddresses(address ipAccountRegistry, address moduleRegistry) external restricted {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        $.ipAccountRegistry = ipAccountRegistry;
        $.moduleRegistry = moduleRegistry;
    }

    /// @notice Sets a batch of permissions in a single transaction.
    /// @dev This function allows setting multiple permissions at once. Pausable.
    /// @param permissions An array of `Permission` structs, each representing the permission to be set.
    function setBatchPermissions(AccessPermission.Permission[] memory permissions) external {
        // TODO: removed pause.
        for (uint256 i = 0; i < permissions.length; ) {
            setPermission(
                permissions[i].ipAccount,
                permissions[i].signer,
                permissions[i].to,
                permissions[i].func,
                permissions[i].permission
            );
            unchecked {
                i += 1;
            }
        }
    }

    /// @notice Sets the permission for all IPAccounts
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param signer The address that can call `to` on behalf of the IP account
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The new permission level
    function setGlobalPermission(address signer, address to, bytes4 func, uint8 permission) external restricted {
        if (signer == address(0)) {
            revert Errors.AccessController__SignerIsZeroAddress();
        }
        // permission must be one of ABSTAIN, ALLOW, DENY
        if (permission > 2) {
            revert Errors.AccessController__PermissionIsNotValid();
        }
        _setPermission(address(0), signer, to, func, permission);
        emit PermissionSet(address(0), address(0), signer, to, func, permission);
    }

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
    function setPermission(address ipAccount, address signer, address to, bytes4 func, uint8 permission) public {
        // TODO: Reintroduce pause
        // IPAccount and signer does not support wildcard permission
        if (ipAccount == address(0)) {
            revert Errors.AccessController__IPAccountIsZeroAddress();
        }
        if (signer == address(0)) {
            revert Errors.AccessController__SignerIsZeroAddress();
        }
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        if (!IIPAccountRegistry($.ipAccountRegistry).isIpAccount(ipAccount)) {
            revert Errors.AccessController__IPAccountIsNotValid(ipAccount);
        }
        // permission must be one of ABSTAIN, ALLOW, DENY
        if (permission > 2) {
            revert Errors.AccessController__PermissionIsNotValid();
        }
        if (!IModuleRegistry($.moduleRegistry).isRegistered(msg.sender) && ipAccount != msg.sender) {
            revert Errors.AccessController__CallerIsNotIPAccount();
        }
        _setPermission(ipAccount, signer, to, func, permission);

        emit PermissionSet(IIPAccount(payable(ipAccount)).owner(), ipAccount, signer, to, func, permission);
    }

    /// @notice Checks the permission level for a specific function call. Reverts if permission is not granted.
    /// Otherwise, the function is a noop.
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    // solhint-disable code-complexity
    function checkPermission(address ipAccount, address signer, address to, bytes4 func) external view {
        // The ipAccount is restricted to interact exclusively with registered modules.
        // This includes initiating calls to these modules and receiving calls from them.
        // Additionally, it can modify Permissions settings.
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        if (
            to != address(this) &&
            !IModuleRegistry($.moduleRegistry).isRegistered(to) &&
            !IModuleRegistry($.moduleRegistry).isRegistered(signer)
        ) {
            revert Errors.AccessController__BothCallerAndRecipientAreNotRegisteredModule(signer, to);
        }
        // Must be a valid IPAccount
        if (!IIPAccountRegistry($.ipAccountRegistry).isIpAccount(ipAccount)) {
            revert Errors.AccessController__IPAccountIsNotValid(ipAccount);
        }
        // Owner can call all functions of all modules
        if (IIPAccount(payable(ipAccount)).owner() == signer) {
            return;
        }
        uint functionPermission = getPermission(ipAccount, signer, to, func);
        // Specific function permission overrides wildcard/general permission
        if (functionPermission == AccessPermission.ALLOW) {
            return;
        }

        // If specific function permission is ABSTAIN, check module level permission
        if (functionPermission == AccessPermission.ABSTAIN) {
            uint8 modulePermission = getPermission(ipAccount, signer, to, bytes4(0));
            // Return true if allow to call all functions of the module
            if (modulePermission == AccessPermission.ALLOW) {
                return;
            }
            // If module level permission is ABSTAIN, check transaction signer level permission
            if (modulePermission == AccessPermission.ABSTAIN) {
                if (getPermission(address(0), signer, to, func) == AccessPermission.ALLOW) {
                    return;
                }
                // Pass if the ipAccount allow the signer can call all functions of all modules
                // Otherwise, revert
                if (getPermission(ipAccount, signer, address(0), bytes4(0)) == AccessPermission.ALLOW) {
                    return;
                }
                revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
            }
            revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
        }
        revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
    }

    /// @notice Returns the permission level for a specific function call.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @return permission The current permission level for the function call on `to` by the `signer` for `ipAccount`
    function getPermission(address ipAccount, address signer, address to, bytes4 func) public view returns (uint8) {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        return $.encodedPermissions[_encodePermission(ipAccount, signer, to, func)];
    }

    /// @dev The permission parameters will be encoded into bytes32 as key in the permissions mapping to save storage
    function _setPermission(address ipAccount, address signer, address to, bytes4 func, uint8 permission) internal {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        $.encodedPermissions[_encodePermission(ipAccount, signer, to, func)] = permission;
    }

    /// @dev encode permission to hash (bytes32)
    function _encodePermission(
        address ipAccount,
        address signer,
        address to,
        bytes4 func
    ) internal view returns (bytes32) {
        if (ipAccount == address(0)) {
            return keccak256(abi.encode(address(0), address(0), signer, to, func));
        }
        return keccak256(abi.encode(IIPAccount(payable(ipAccount)).owner(), ipAccount, signer, to, func));
    }

    /// @dev Returns the storage struct of AccessController.
    function _getAccessControllerStorage() private pure returns (AccessControllerStorage storage $) {
        assembly {
            $.slot := AccessControllerStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
