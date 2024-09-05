// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "../../../../contracts/interfaces/modules/base/IModule.sol";
import { IIPAccountRegistry } from "../../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IPAccountChecker } from "../../../../contracts/lib/registries/IPAccountChecker.sol";
import { IModuleRegistry } from "../../../../contracts/interfaces/registries/IModuleRegistry.sol";
import { AccessControlled } from "../../../../contracts/access/AccessControlled.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";

/// @title MockAccessControlledModule
/// @dev This contract is a mock implementation of an access-controlled module, used for testing purposes.
/// It demonstrates the use of access control checks in function calls.
contract MockAccessControlledModule is BaseModule, AccessControlled {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;

    IModuleRegistry public moduleRegistry;
    string public name;

    /// @notice Creates a new MockAccessControlledModule instance.
    /// @param accessController The address of the AccessController contract.
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract.
    /// @param moduleRegistry_ The address of the ModuleRegistry contract.
    /// @param name_ The name of the module.
    constructor(
        address accessController,
        address ipAccountRegistry,
        address moduleRegistry_,
        string memory name_
    ) AccessControlled(accessController, ipAccountRegistry) {
        moduleRegistry = IModuleRegistry(moduleRegistry_);
        name = name_;
    }

    /// @notice A function that can only be called by an IP account.
    /// @param param A string parameter for demonstration.
    /// @param success A boolean to simulate function success or failure.
    /// @return The input string parameter if the call is successful.
    /// @dev This function reverts if the `success` parameter is false.
    function onlyIpAccountFunction(
        string memory param,
        bool success
    ) external view onlyIpAccount returns (string memory) {
        if (!success) {
            revert("expected failure");
        }
        return param;
    }

    /// @notice A function that can be called by an IP account or with specific permission.
    /// @param ipAccount The address of the IP account.
    /// @param param A string parameter for demonstration.
    /// @param success A boolean to simulate function success or failure.
    /// @return The input string parameter if the call is successful.
    /// @dev This function reverts if the `success` parameter is false.
    function ipAccountOrPermissionFunction(
        address ipAccount,
        string memory param,
        bool success
    ) external view verifyPermission(ipAccount) returns (string memory) {
        if (!success) {
            revert("expected failure");
        }
        return param;
    }

    /// @notice A function with a custom permission check by using the `_hasPermission` function.
    /// @param ipAccount The address of the IP account.
    /// @param param A string parameter for demonstration.
    /// @param success A boolean to simulate function success or failure.
    /// @return The input string parameter if the call is successful.
    /// @dev This function performs a custom permission check and reverts if the `success` parameter is false.
    /// instead of using the `verifyPermission` modifier.
    /// it uses the `_hasPermission` function within the function body to perform the permission check.
    function customizedFunction(
        address ipAccount,
        string memory param,
        bool success
    ) external view returns (string memory) {
        if (!_hasPermission(ipAccount)) {
            revert("expected permission check failure");
        }
        if (!success) {
            revert("expected failure");
        }
        return param;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
