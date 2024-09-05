// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title IModuleRegistry
/// @dev This interface defines the methods for a module registry in the Story Protocol.
interface IModuleRegistry {
    /// @notice Emitted when a new module is added to the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleAdded(string name, address indexed module, bytes4 indexed moduleTypeInterfaceId, string moduleType);

    /// @notice Emitted when a module is removed from the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleRemoved(string name, address indexed module);

    /// @notice Returns the address of a registered module by its name.
    /// @param name The name of the module.
    /// @return moduleAddress The address of the module.
    function getModule(string memory name) external view returns (address);

    /// @notice Returns the module type of a registered module by its address.
    /// @param moduleAddress The address of the module.
    /// @return moduleType The type of the module as a string.
    function getModuleType(address moduleAddress) external view returns (string memory);

    /// @notice Returns the interface ID of a registered module type.
    /// @param moduleType The name of the module type.
    /// @return moduleTypeInterfaceId The interface ID of the module type as bytes4.
    function getModuleTypeInterfaceId(string memory moduleType) external view returns (bytes4);

    /// @notice Registers a new module type in the registry associate with an interface.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module type to be registered.
    /// @param interfaceId The interface ID associated with the module type.
    function registerModuleType(string memory name, bytes4 interfaceId) external;

    /// @notice Removes a module type from the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module type to be removed.
    function removeModuleType(string memory name) external;

    /// @notice Registers a new module in the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external;

    /// @notice Registers a new module in the registry with an associated module type.
    /// @param name The name of the module to be registered.
    /// @param moduleAddress The address of the module.
    /// @param moduleType The type of the module being registered.
    function registerModule(string memory name, address moduleAddress, string memory moduleType) external;

    /// @notice Removes a module from the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module.
    function removeModule(string memory name) external;

    /// @notice Checks if a module is registered in the protocol.
    /// @param moduleAddress The address of the module.
    /// @return isRegistered True if the module is registered, false otherwise.
    function isRegistered(address moduleAddress) external view returns (bool);
}
