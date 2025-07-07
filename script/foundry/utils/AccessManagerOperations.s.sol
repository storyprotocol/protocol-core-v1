/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";

// script
import { JSONTxWriter } from "./JSONTxWriter.s.sol";

/// @title AccessManagerOperations
/// @notice Script to generate tx json to schedule, execute, and cancel upgrades for the protocol
/// through the AccessManager via multisig.
abstract contract AccessManagerOperations is Script, JSONTxWriter {
    AccessManager internal protocolAccessManager;

    /// @notice constructor
    constructor() {
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
    }

    function run() public virtual {
        console2.log("Generating actions...");
        _generate();
        console2.log("Writing tx json...");
        _writeFiles();
    }

    /// @notice generate the tx json. Should be overridden by the child contract
    /// @dev Child contract should call _generateAction for each action to be scheduled, executed, and cancelled
    function _generate() internal virtual;

    /// @notice generate the 3 JSON (schedule, execute, cancel) for a single target
    /// @param from The addresses of the sender for the schedule, execute, and cancel
    /// @param target The address of the contract to call
    /// @param value The value to send with the call
    /// @param data The encoded target method call
    /// @param delay The delay for the access manager operation. 0 is minimum delay
    function _generateAction(
        address[] memory from,
        address target,
        uint256 value,
        bytes memory data,
        uint256 delay
    ) internal {
        _scheduleAction(from[0], target, value, data, delay);
        _executeAction(from[1], target, value, data);
        _cancelAction(from[2], from[0], target, value, data);
    }

    /// @notice Encodes the call to AccessManager.schedule
    /// @param from The address of the sender
    /// @param target The address of the contract to call
    /// @param value The value to send with the call
    /// @param data The encoded target method call
    /// @param delay The delay for the access manager operation. Must be >= minDelay
    function _scheduleAction(
        address from,
        address target,
        uint256 value,
        bytes memory data,
        uint256 delay
    ) internal {
        bytes memory _txData = abi.encodeWithSelector(
            AccessManager.schedule.selector,
            target,
            data,
            uint48(0)
        );
        _saveTx(Operation.SCHEDULE, from, address(protocolAccessManager), value, _txData, string.concat(action, "-schedule"));
    }

    /// @notice Encodes the call to AccessManager.execute
    /// @param target The address of the contract to call
    /// @param value The value to send with the call
    /// @param data The encoded target method call
    function _executeAction(
        address from,
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        bytes memory _txData = abi.encodeWithSelector(
            AccessManager.execute.selector,
            target,
            data
        );
        _saveTx(Operation.EXECUTE, from, address(protocolAccessManager), value, _txData, string.concat(action, "-execute"));
    }

    /// @notice Encodes the call to AccessManager.cancel
    /// @param target The address of the contract to call
    /// @param value The value sent to scheduled call
    /// @param data The encoded target method call
    function _cancelAction(
        address from,
        address scheduleCaller,
        address target,
        uint256 value,
        bytes memory data
    ) internal {
        bytes memory _txData = abi.encodeWithSelector(
            AccessManager.cancel.selector,
            scheduleCaller,
            target,
            data
        );
        _saveTx(Operation.CANCEL, from, address(protocolAccessManager), value, _txData, string.concat(action, "-cancel"));
    }

    /// @notice Encodes regular txs
    /// @param from The address of the sender
    /// @param txData The encoded target method call
    function _generateRegularTx(
        address from,
        bytes memory txData
    ) internal {
        _saveTx(Operation.REGULAR_TX, from, address(protocolAccessManager), 0, txData, string.concat(action, "-regular"));
    }
}