// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { CREATE3 } from "@solady/src/utils/CREATE3.sol";
import { ICreate3Deployer } from "./ICreate3Deployer.sol";

contract Create3Deployer is ICreate3Deployer {
    /// @inheritdoc	ICreate3Deployer
    function deploy(bytes32 salt, bytes calldata creationCode) external payable returns (address) {
        return CREATE3.deploy(salt, creationCode, msg.value);
    }

    /// @inheritdoc	ICreate3Deployer
    function getDeployed(address deployer, bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}
