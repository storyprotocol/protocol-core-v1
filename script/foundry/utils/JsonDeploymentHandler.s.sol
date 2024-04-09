// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";

contract JsonDeploymentHandler is Script {
    using StringUtil for uint256;
    using stdJson for string;

    // keep all variables private to avoid conflicts
    string private output;
    string private readJson;
    string private chainId;
    string private key;
    string private internalKey = "key";

    constructor(string memory _key) {
        chainId = (block.chainid).toString();
        key = _key;
    }

    function _readAddress(string memory readPath) internal view returns (address) {
        try vm.parseJsonAddress(readJson, readPath) returns (address addr) {
            return addr;
        } catch {
            return address(0);
        }
    }

    function _readDeployment() internal {
        string memory root = vm.projectRoot();
        string memory filePath = string.concat("/deploy-out/deployment-", (block.chainid).toString(), ".json");
        string memory path = string.concat(root, filePath);
        readJson = vm.readFile(path);
    }

    function _writeAddress(string memory contractKey, address newAddress) internal {
        output = vm.serializeAddress(internalKey, contractKey, newAddress);
    }

    function _writeToJson(string memory contractKey, string memory value) internal {
        vm.writeJson(value, string.concat("./deploy-out/deployment-", chainId, ".json"), contractKey);
    }

    function _writeDeployment() internal {
        vm.writeJson(output, string.concat("./deploy-out/deployment-", chainId, ".json"), string.concat(".", key));
    }
}
