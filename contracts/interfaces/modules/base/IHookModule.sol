// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "./IModule.sol";

/// @notice Hook Module Interface
interface IHookModule is IModule {
    /// @notice Verify if the caller can pass the hook
    /// @param caller The address of the caller
    /// @param data The arbitrary data to be verified
    /// @return bool Whether or not the caller has passed the hook's verification
    function verify(address caller, bytes calldata data) external returns (bool);

    /// @notice Validates the configuration for the hook.
    /// @param configData The configuration data for the hook.
    function validateConfig(bytes calldata configData) external view;
}
