// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { StringUtil } from "./StringUtil.sol";

contract JsonBatchTxHelper is Script {
    using StringUtil for uint256;
    using stdJson for string;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
        string txType; // schedule, execute, cancel
    }

    Transaction[] private transactions;
    string private chainId;

    constructor() {
        chainId = (block.chainid).toString();
    }

    function _writeTx(address _to, uint256 _value, bytes memory _data, string memory _type) internal {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            operation: 0,
            txType: _type
        }));
        console2.log("Added tx to ", _to);
        console2.log("Value: ", _value);
        console2.log("Data: ");
        console2.logBytes(_data);
        console2.log("Operation: 0");
    }

    function _writeBatchTxsOutput(string memory _action, string memory _type) internal {
        string memory json = "[";
        for (uint i = 0; i < transactions.length; i++) {
            if (keccak256(abi.encodePacked(transactions[i].txType)) != keccak256(abi.encodePacked(_type))) continue;
            if (i > 0) {
                json = string(abi.encodePacked(json, ","));
            }
            json = string(abi.encodePacked(json, "{"));
            json = string(abi.encodePacked(json, '"to":"', vm.toString(transactions[i].to), '",'));
            json = string(abi.encodePacked(json, '"value":', vm.toString(transactions[i].value), ','));
            json = string(abi.encodePacked(json, '"data":"', vm.toString(transactions[i].data), '",'));
            json = string(abi.encodePacked(json, '"operation":', vm.toString(transactions[i].operation)));
            json = string(abi.encodePacked(json, "}"));
        }
        json = string(abi.encodePacked(json, "]"));

        string memory filename = string(abi.encodePacked("./deploy-out/", _action, "-", chainId, ".json"));
        vm.writeFile(filename, json);
        console2.log("Wrote batch txs to ", filename);
    }
}