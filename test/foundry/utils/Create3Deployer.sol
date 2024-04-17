// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { CREATE3 } from "@solady/src/utils/CREATE3.sol";

library Create3Deployer {
    function deploy(bytes32 salt, bytes calldata creationCode) external returns (address) {
        return CREATE3.deploy(salt, creationCode, 0);
    }

    function getDeployed(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}
