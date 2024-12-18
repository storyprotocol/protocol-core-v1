// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { CREATE3 } from "@solady/src/utils/CREATE3.sol";
import { ICreate3Deployer } from "./ICreate3Deployer.sol";

contract Create3Deployer is ICreate3Deployer {
    /// @inheritdoc	ICreate3Deployer
    function deployDeterministic(bytes memory creationCode, bytes32 salt) external payable returns (address deployed) {
        return CREATE3.deployDeterministic(creationCode, salt);
    }

    /// @inheritdoc	ICreate3Deployer
    function predictDeterministicAddress(bytes32 salt) external view returns (address deployed) {
        return CREATE3.predictDeterministicAddress(salt);
    }
}
