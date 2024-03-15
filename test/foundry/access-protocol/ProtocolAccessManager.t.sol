// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { ProtocolRoles } from "contracts/lib/access-protocol/ProtocolRoles.sol";
import { ProtocolAccessManager } from "contracts/access-protocol/ProtocolAccessManager.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract ProtocolAccessManagerTest is BaseTest {

    function setUp() public override {
        super.setUp();
        deployIntegration();
        postDeploymentSetup();
    }

    function test_constructor() public {
        address admin = address(0x1);
        address upgrader = address(0x2);
        uint32 grantDelay = 10;
        uint32 execDelay = 20;
        ProtocolAccessManager accessManager = new ProtocolAccessManager(
            admin,
            upgrader,
            grantDelay,
            execDelay)
        ;
        (bool isMember, uint32 executionDelay) = accessManager.hasRole(ProtocolRoles.UPGRADER, upgrader);
        assertTrue(isMember);
        assertEq(executionDelay, execDelay);
        assertEq(accessManager.getRoleAdmin(ProtocolRoles.UPGRADER), ProtocolRoles.ADMIN);

        (isMember, executionDelay) = accessManager.hasRole(ProtocolRoles.ADMIN, admin);
        assertTrue(isMember);
        assertEq(executionDelay, 0); // Admin should not execute, only grant
    }

   
}
