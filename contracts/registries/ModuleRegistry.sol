// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { IModuleRegistry } from "../interfaces/registries/IModuleRegistry.sol";
import { Errors } from "../lib/Errors.sol";
import { IModule } from "../interfaces/modules/base/IModule.sol";
import { MODULE_TYPE_DEFAULT } from "../lib/modules/Module.sol";

/// @title ModuleRegistry
/// @notice This contract is used to register and track modules in the protocol.
contract ModuleRegistry is IModuleRegistry, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using ERC165Checker for address;

    /// @dev Storage for the ModuleRegistry.
    /// @param modules The address of a registered module by its name.
    /// @param moduleTypes The module type of a registered module by its address.
    /// @param allModuleTypes The interface ID of a registered module type.
    /// @custom:storage-location erc7201:story-protocol.ModuleRegistry
    struct ModuleRegistryStorage {
        mapping(string moduleName => address moduleAddress) modules;
        mapping(address moduleAddress => string moduleType) moduleTypes;
        mapping(string moduleType => bytes4 moduleTypeInterface) allModuleTypes;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.ModuleRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ModuleRegistryStorageLocation =
        0xa17d78ae7aee011aefa3f1388acb36741284b44eb3fcffe23ecc3a736eaa2700;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the governance.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.ModuleRegistry__ZeroAccessManager();
        }
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();

        // Register the default module types
        _getModuleRegistryStorage().allModuleTypes[MODULE_TYPE_DEFAULT] = type(IModule).interfaceId;
    }

    /// @notice Registers a new module type in the registry associate with an interface.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module type to be registered.
    /// @param interfaceId The interface ID associated with the module type.
    function registerModuleType(string memory name, bytes4 interfaceId) external override restricted {
        ModuleRegistryStorage storage $ = _getModuleRegistryStorage();
        if (interfaceId == 0) {
            revert Errors.ModuleRegistry__InterfaceIdZero();
        }
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        if ($.allModuleTypes[name] != 0) {
            revert Errors.ModuleRegistry__ModuleTypeAlreadyRegistered();
        }
        $.allModuleTypes[name] = interfaceId;
    }

    /// @notice Removes a module type from the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module type to be removed.
    function removeModuleType(string memory name) external override restricted {
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        ModuleRegistryStorage storage $ = _getModuleRegistryStorage();
        if ($.allModuleTypes[name] == 0) {
            revert Errors.ModuleRegistry__ModuleTypeNotRegistered();
        }
        delete $.allModuleTypes[name];
    }

    /// @notice Registers a new module in the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external restricted {
        _registerModule(name, moduleAddress, MODULE_TYPE_DEFAULT);
    }

    /// @notice Registers a new module in the registry with an associated module type.
    /// @param name The name of the module to be registered.
    /// @param moduleAddress The address of the module.
    /// @param moduleType The type of the module being registered.
    function registerModule(string memory name, address moduleAddress, string memory moduleType) external restricted {
        _registerModule(name, moduleAddress, moduleType);
    }

    /// @notice Removes a module from the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module.
    function removeModule(string memory name) external restricted {
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        ModuleRegistryStorage storage $ = _getModuleRegistryStorage();
        if ($.modules[name] == address(0)) {
            revert Errors.ModuleRegistry__ModuleNotRegistered();
        }

        address module = $.modules[name];
        delete $.modules[name];
        delete $.moduleTypes[module];

        emit ModuleRemoved(name, module);
    }

    /// @notice Checks if a module is registered in the protocol.
    /// @param moduleAddress The address of the module.
    /// @return isRegistered True if the module is registered, false otherwise.
    function isRegistered(address moduleAddress) external view returns (bool) {
        ModuleRegistryStorage storage $ = _getModuleRegistryStorage();
        return bytes($.moduleTypes[moduleAddress]).length > 0;
    }

    /// @notice Returns the address of a module.
    /// @param name The name of the module.
    /// @return The address of the module.
    function getModule(string memory name) external view returns (address) {
        return _getModuleRegistryStorage().modules[name];
    }

    /// @notice Returns the module type of a given module address.
    /// @param moduleAddress The address of the module.
    /// @return The type of the module as a string.
    function getModuleType(address moduleAddress) external view returns (string memory) {
        return _getModuleRegistryStorage().moduleTypes[moduleAddress];
    }

    /// @notice Returns the interface ID associated with a given module type.
    /// @param moduleType The type of the module as a string.
    /// @return The interface ID of the module type as bytes4.
    function getModuleTypeInterfaceId(string memory moduleType) external view returns (bytes4) {
        return _getModuleRegistryStorage().allModuleTypes[moduleType];
    }

    /// @dev Registers a new module in the registry.
    // solhint-disable code-complexity
    function _registerModule(string memory name, address moduleAddress, string memory moduleType) internal {
        ModuleRegistryStorage storage $ = _getModuleRegistryStorage();
        if (moduleAddress == address(0)) {
            revert Errors.ModuleRegistry__ModuleAddressZeroAddress();
        }
        if (bytes(moduleType).length == 0) {
            revert Errors.ModuleRegistry__ModuleTypeEmptyString();
        }
        if (moduleAddress.code.length == 0) {
            revert Errors.ModuleRegistry__ModuleAddressNotContract();
        }
        if (bytes($.moduleTypes[moduleAddress]).length > 0) {
            revert Errors.ModuleRegistry__ModuleAlreadyRegistered();
        }
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        if ($.modules[name] != address(0)) {
            revert Errors.ModuleRegistry__NameAlreadyRegistered();
        }
        if (!IModule(moduleAddress).name().equal(name)) {
            revert Errors.ModuleRegistry__NameDoesNotMatch();
        }
        bytes4 moduleTypeInterfaceId = $.allModuleTypes[moduleType];
        if (moduleTypeInterfaceId == 0) {
            revert Errors.ModuleRegistry__ModuleTypeNotRegistered();
        }
        if (!moduleAddress.supportsInterface(moduleTypeInterfaceId)) {
            revert Errors.ModuleRegistry__ModuleNotSupportExpectedModuleTypeInterfaceId();
        }
        $.modules[name] = moduleAddress;
        $.moduleTypes[moduleAddress] = moduleType;

        emit ModuleAdded(name, moduleAddress, moduleTypeInterfaceId, moduleType);
    }

    /// @dev Returns the storage struct of the ModuleRegistry.
    function _getModuleRegistryStorage() private pure returns (ModuleRegistryStorage storage $) {
        assembly {
            $.slot := ModuleRegistryStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
