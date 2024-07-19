// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console2 } from "forge-std/console2.sol";

import { UpgradedImplHelper } from "../utils/upgrades/UpgradedImplHelper.sol";
import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";

contract JsonDeploymentHandler is Script {
    using StringUtil for uint256;
    using stdJson for string;

    // keep all variables private to avoid conflicts
    string private output;
    string private readJson;
    string private chainId;
    string private internalKey = "main";

    constructor(string memory _key) {
        chainId = (block.chainid).toString();
        internalKey = _key;
    }

    ///////////////////// Deployment JSON /////////////////////

    function _readDeployment() internal {
        string memory root = vm.projectRoot();
        string memory filePath = string.concat("/deploy-out/deployment-", (block.chainid).toString(), ".json");
        console2.log(string.concat("Reading deployment file: ", filePath));
        string memory path = string.concat(root, filePath);
        readJson = vm.readFile(path);
        console2.log(readJson);
    }

    function _readAddress(string memory key) internal view returns (address) {
        console2.log(string.concat("Reading ", key, "..."));
        address addr = vm.parseJsonAddress(readJson, string.concat(".", internalKey, ".", key));
        console2.log(addr);
        return addr;
    }

    function _writeAddress(string memory contractKey, address newAddress) internal {
        output = vm.serializeAddress("", contractKey, newAddress);
    }

    function _writeDeployment() internal {
        vm.writeJson(output, string.concat("./deploy-out/deployment-", chainId, ".json"), string.concat(".", internalKey));
    }

    ///////////////////// UPGRADES JSON /////////////////////
    function _readProposalFile(string memory version) internal {
        string memory root = vm.projectRoot();
        string memory filePath = string.concat("/deploy-out/upgrade-", version, "-", (block.chainid).toString(), ".json");
        string memory path = string.concat(root, filePath);
        readJson = vm.readFile(path);
    }

    function _readUpgradeProposal(string memory key) internal view returns(UpgradedImplHelper.UpgradeProposal memory) {
        console2.log(string.concat("Reading ", key, "..."));
        address proxy = vm.parseJsonAddress(readJson, string.concat(".", internalKey, ".", string.concat(key, "-NewImpl")));
        address newImpl = vm.parseJsonAddress(readJson, string.concat(".", internalKey, ".", string.concat(key, "-NewImpl")));

        return UpgradedImplHelper.UpgradeProposal({key: key, proxy: proxy, newImpl: newImpl});
    }

    function _writeUpgradeProposalAddress(string memory contractKey, address proxy, address newImpl) private {
        string memory proxyKey = string.concat(contractKey, "-Proxy");
        output = vm.serializeAddress("", proxyKey, proxy);
        string memory newImplKey = string.concat(contractKey, "-NewImpl");
        output = vm.serializeAddress("", newImplKey, newImpl);
    }

    function _writeUpgradeProposals(string memory version, UpgradedImplHelper.UpgradeProposal[] memory proposals) internal {
        for (uint256 i = 0; i < proposals.length; i++) {
            UpgradedImplHelper.UpgradeProposal memory p = proposals[i];
            _writeUpgradeProposalAddress(p.key, p.proxy, p.newImpl);
        }
        string memory path = string.concat("./deploy-out/upgrade-", version, "-");
        console2.log(output);
        vm.writeJson(output, string.concat(path, chainId, ".json"), string.concat(".", internalKey));
    }
}
