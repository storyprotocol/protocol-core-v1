/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";

// script
import { BroadcastManager } from "../utils/BroadcastManager.s.sol";
import { StorageLayoutChecker } from "../utils/upgrades/StorageLayoutCheck.s.sol";
import { JsonDeploymentHandler } from "../utils/JsonDeploymentHandler.s.sol";
import { StringUtil } from "../utils/StringUtil.sol";

contract RoleGranter is Script, BroadcastManager, JsonDeploymentHandler {


    constructor() JsonDeploymentHandler("main") {}

    function run() public virtual {
        _readDeployment(); // JsonDeploymentHandler.s.sol
        _beginBroadcast(); // BroadcastManager.s.sol

        AccessManager am = AccessManager(_readAddress("ProtocolAccessManager"));

        console2.log("multisig");
        console2.log(multisig);

        console2.log("check roles multisig");
        (bool hasRole, uint32 data) = am.hasRole(ProtocolAdmin.UPGRADER_ROLE, multisig);
        console2.log(hasRole);
        (hasRole, data) = am.hasRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, multisig);
        console2.log(hasRole);

        console2.log("deployer");
        console2.log(deployer);

        console2.log("check roles deployer");
        (hasRole, data) = am.hasRole(ProtocolAdmin.UPGRADER_ROLE, deployer);
        console2.log(hasRole);
        (hasRole, data) = am.hasRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, deployer);
        console2.log(hasRole);
        vm.prank(multisig);
        am.grantRole(ProtocolAdmin.UPGRADER_ROLE, deployer, 0);

        _endBroadcast(); // BroadcastManager.s.sol
    }
}
