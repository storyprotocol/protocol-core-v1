/* solhint-disable no-console */
/* solhint-disable quotes */
// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { StringUtil } from "./StringUtil.sol";

/// @title JSONTxWriter
/// @notice Writes the tx json files for the access manager operations
contract JSONTxWriter is Script {
    using StringUtil for uint256;
    using stdJson for string;

    enum Operation {
        SCHEDULE,
        EXECUTE,
        CANCEL,
        REGULAR_TX // Usually calls directly to the access manager, like renounce roles
    }

    /// @notice A struct to store the transaction details
    /// @param from The address of the sender
    /// @param to The address of the contract to call
    /// @param value The value to send with the call
    /// @param data The encoded target method call
    /// @param operation Needed for Safe. 0 is call, 1 is delegatecall
    /// @param comment The comment for the transaction
    struct Transaction {
        address from;
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
        string comment;
    }

    /// @notice A mapping to store the transactions to batch for each access manager operation
    mapping(Operation => Transaction[]) public transactions;

    /// @notice The chain id
    string private chainId;

    /// @notice The action name
    string internal action;

    constructor(string memory _action) {
        action = _action;
        chainId = (block.chainid).toString();
    }

    /// @notice Saves a transaction to the mapping
    /// @param _accessManagerOp The access manager operation
    /// @param _from The address of the sender
    /// @param _to The address of the contract to call
    /// @param _value The value to send with the call
    /// @param _data The encoded target method call
    /// @param _comment The comment for the transaction
    function _saveTx(
        Operation _accessManagerOp,
        address _from,
        address _to,
        uint256 _value,
        bytes memory _data,
        string memory _comment
    ) internal {
        transactions[_accessManagerOp].push(
            Transaction({ from: _from, to: _to, value: _value, data: _data, operation: 0, comment: _comment })
        );
        console2.log("Added tx ", uint8(_accessManagerOp));
        console2.log("To: ", _to);
        console2.log("Value: ", _value);
        console2.log("Data: ");
        console2.logBytes(_data);
        console2.log("Operation: 0");
        console2.log("Comment: ", _comment);
    }

    /// @notice Writes all the tx json files for the access manager operations
    function _writeFiles() internal {
        console2.log("Writing txs to file");
        Transaction[] memory _transactions = transactions[Operation.SCHEDULE];
        console2.log("Schedule txs: ", _transactions.length);
        if (_transactions.length > 0) {
            _writeTxArrayToJson(Operation.SCHEDULE, _transactions);
        }

        _transactions = transactions[Operation.EXECUTE];
        console2.log("Execute txs: ", _transactions.length);
        if (_transactions.length > 0) {
            _writeTxArrayToJson(Operation.EXECUTE, _transactions);
        }

        _transactions = transactions[Operation.CANCEL];
        console2.log("Cancel txs: ", _transactions.length);
        if (_transactions.length > 0) {
            _writeTxArrayToJson(Operation.CANCEL, _transactions);
        }

        _transactions = transactions[Operation.REGULAR_TX];
        console2.log("Regular txs: ", _transactions.length);
        if (_transactions.length > 0) {
            _writeTxArrayToJson(Operation.REGULAR_TX, _transactions);
        }
    }

    /// @notice Writes a json files for the access manager operations
    /// @param _accessManagerOp The access manager operation
    /// @param txArray The transactions to write to the json file
    function _writeTxArrayToJson(Operation _accessManagerOp, Transaction[] memory txArray) internal {
        string memory json = "[";
        for (uint i = 0; i < txArray.length; i++) {
            if (i > 0) {
                json = string(abi.encodePacked(json, ","));
            }
            json = string(abi.encodePacked(json, "{"));
            json = string(abi.encodePacked(json, '"from":"', vm.toString(txArray[i].from), '",'));
            json = string(abi.encodePacked(json, '"to":"', vm.toString(txArray[i].to), '",'));
            json = string(abi.encodePacked(json, '"value":', vm.toString(txArray[i].value), ","));
            json = string(abi.encodePacked(json, '"data":"', vm.toString(txArray[i].data), '",'));
            json = string(abi.encodePacked(json, '"operation":', vm.toString(txArray[i].operation), ","));
            json = string(abi.encodePacked(json, '"comment":"', txArray[i].comment, '"'));
            json = string(abi.encodePacked(json, "}"));
        }
        json = string(abi.encodePacked(json, "]"));

        string memory filename = string(
            abi.encodePacked(
                "./script/foundry/admin-actions/output/",
                chainId,
                "/",
                action,
                "-",
                _accessManagerOpToString(_accessManagerOp),
                ".json"
            )
        );
        vm.writeFile(filename, json);
        console2.log("Wrote batch txs to ", filename);
    }

    /// @notice Converts the access manager operation to a string
    /// @param _accessManagerOp The access manager operation
    /// @return The string representation of the access manager operation
    function _accessManagerOpToString(Operation _accessManagerOp) internal pure returns (string memory) {
        if (_accessManagerOp == Operation.SCHEDULE) {
            return "schedule";
        } else if (_accessManagerOp == Operation.EXECUTE) {
            return "execute";
        } else if (_accessManagerOp == Operation.CANCEL) {
            return "cancel";
        } else if (_accessManagerOp == Operation.REGULAR_TX) {
            return "regular";
        }
        revert("Invalid operation");
    }
}