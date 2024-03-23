// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";
import { console } from "forge-std/console.sol";

import { StringUtil } from "../StringUtil.sol";

/// @title StorageLayoutChecker
/// @notice Helper contract to check if the storage layout of the contracts is compatible with upgrades
/// @dev Picked relevant functionality from OpenZeppelin's `@openzeppelin/upgrades-core` package.
/// NOTE: Replace this contract for their library, if these issues are resolved

/// MUST be called in scripts that deploy or upgrade contracts
/// MUST be called with `--ffi` flag
contract StorageLayoutChecker is Script {
    function run() public {
        _validate();
    }

    /// @notice Runs the storage layout check
    /// @dev For simplicity and efficiency, we check all the upgradeablecontracts in the project
    /// instead of going 1 by 1 using ffi.
    function _validate() private {
        string[] memory inputs = _buildValidateCommand();
        Vm.FfiResult memory result = _runAsBashCommand(inputs);
        string memory stdout = string(result.stdout);

        // CLI validate command uses exit code to indicate if the validation passed or failed.
        // As an extra precaution, we also check stdout for "SUCCESS" to ensure it actually ran.
        if (result.exitCode == 0 && stdout.toSlice().contains("SUCCESS".toSlice())) {
            return;
        } else if (result.stderr.length > 0) {
            // Validations failed to run
            revert(StringUtil.concat("Failed to run upgrade safety validation: ", string(result.stderr)));
        } else {
            // Validations ran but some contracts were not upgrade safe
            revert(StringUtil.concat("Upgrade safety validation failed:\n", stdout));
        }
    }

    /**
     * @dev Runs an arbitrary command using bash.
     * @param inputs Inputs for a command, e.g. ["grep", "-rl", "0x1234", "out/build-info"]
     * @return The result of the corresponding bash command as a Vm.FfiResult struct
     */
    function _runAsBashCommand(string[] memory inputs) internal returns (Vm.FfiResult memory) {
        string[] memory bashCommand = _toBashCommand(inputs, "bash");
        Vm.FfiResult memory result = vm.tryFfi(bashCommand);
        if (result.exitCode != 0 && result.stdout.length == 0 && result.stderr.length == 0) {
            // On Windows, using the bash executable from WSL leads to a non-zero exit code and no output
            revert(StringUtil.concat('Failed to run bash command with "', bashCommand[0]));
        } else {
            return result;
        }
    }

    /**
     * @dev Converts an array of inputs to a bash command.
     * @param inputs Inputs for a command, e.g. ["grep", "-rl", "0x1234", "out/build-info"]
     * @param bashPath Path to the bash executable or just "bash" if it is in the PATH
     * @return A bash command that runs the given inputs, e.g. ["bash", "-c", "grep -rl 0x1234 out/build-info"]
     */
    function _toBashCommand(string[] memory inputs, string memory bashPath) internal pure returns (string[] memory) {
        string memory commandString;
        for (uint i = 0; i < inputs.length; i++) {
            commandString = string.concat(commandString, inputs[i]);
            if (i != inputs.length - 1) {
                commandString = string.concat(commandString, " ");
            }
        }

        string[] memory result = new string[](3);
        result[0] = bashPath;
        result[1] = "-c";
        result[2] = commandString;
        return result;
    }

    function _buildValidateCommand() private view returns (string[] memory) {
        string memory outDir = "out";

        string[] memory inputBuilder = new string[](255);

        uint8 i = 0;
        // npx @openzeppelin/upgrades-core validate <build-info-dir> --requireReference
        inputBuilder[i++] = "npx";
        inputBuilder[i++] = string.concat("@openzeppelin/upgrades-core");
        inputBuilder[i++] = "validate";
        inputBuilder[i++] = string.concat(outDir, "/build-info");

        inputBuilder[i++] = "--requireReference";

        // Create a copy of inputs but with the correct length
        string[] memory inputs = new string[](i);
        for (uint8 j = 0; j < i; j++) {
            inputs[j] = inputBuilder[j];
        }

        return inputs;
    }
}
