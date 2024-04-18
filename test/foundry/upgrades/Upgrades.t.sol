// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { MockIpRoyaltyVaultV2 } from "../mocks/module/MockIpRoyaltyVaultV2.sol";
import { MockAccessControllerV2 } from "../mocks/module/MockAccessControllerV2.sol";

contract UpgradesTest is BaseTest {
    uint32 execDelay = 600;

    function setUp() public override {
        super.setUp();
        vm.prank(u.admin);
        protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, u.bob, upgraderExecDelay);
    }

    function test_upgradeVaults() public {
        address newVault = address(new MockIpRoyaltyVaultV2(address(royaltyPolicyLAP), address(disputeModule)));
        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            u.bob,
            address(royaltyPolicyLAP),
            RoyaltyPolicyLAP.upgradeVaults.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        vm.prank(u.bob);
        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            address(royaltyPolicyLAP),
            abi.encodeCall(RoyaltyPolicyLAP.upgradeVaults, (newVault)),
            0 // earliest time possible, upgraderExecDelay
        );
        vm.warp(upgraderExecDelay + 1);

        vm.prank(u.bob);
        royaltyPolicyLAP.upgradeVaults(newVault);

        assertEq(ipRoyaltyVaultBeacon.implementation(), newVault);
    }

    function test_upgradeAccessController() public {
        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            u.bob,
            address(accessController),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);

        address newAccessController = address(
            new MockAccessControllerV2(address(ipAccountRegistry), address(moduleRegistry))
        );
        vm.prank(u.bob);
        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            address(accessController),
            abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (newAccessController, abi.encodeCall(MockAccessControllerV2.initialize, ()))
            ),
            0 // earliest time possible, upgraderExecDelay
        );
        vm.warp(upgraderExecDelay + 1);

        vm.prank(u.bob);
        accessController.upgradeToAndCall(newAccessController, abi.encodeCall(MockAccessControllerV2.initialize, ()));

        assertEq(MockAccessControllerV2(address(accessController)).get(), "initialized");
    }

    function test_deploymentSetup() public {
        // Deployer doesn't have the roles
        (bool isMember, uint32 executionDelay) = protocolAccessManager.hasRole(
            ProtocolAdmin.PROTOCOL_ADMIN_ROLE,
            deployer
        );
        assertFalse(isMember);
        assertEq(executionDelay, 0);
        (isMember, executionDelay) = protocolAccessManager.hasRole(ProtocolAdmin.UPGRADER_ROLE, deployer);
        assertFalse(isMember);
        assertEq(executionDelay, 0);
        (isMember, executionDelay) = protocolAccessManager.hasRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, deployer);
        assertFalse(isMember);
        assertEq(executionDelay, 0);

        (isMember, executionDelay) = protocolAccessManager.hasRole(ProtocolAdmin.PROTOCOL_ADMIN_ROLE, multisig);
        assertTrue(isMember);
        assertEq(executionDelay, 0);
        (isMember, executionDelay) = protocolAccessManager.hasRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, multisig);
        assertTrue(isMember);
        assertEq(executionDelay, 0);
        (isMember, executionDelay) = protocolAccessManager.hasRole(
            ProtocolAdmin.PAUSE_ADMIN_ROLE,
            address(protocolPauser)
        );
        assertTrue(isMember);
        assertEq(executionDelay, 0);
        (isMember, executionDelay) = protocolAccessManager.hasRole(ProtocolAdmin.UPGRADER_ROLE, multisig);
        assertTrue(isMember);
        assertEq(executionDelay, execDelay);

        // Target function role wiring

        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            multisig,
            address(royaltyPolicyLAP),
            RoyaltyPolicyLAP.upgradeVaults.selector
        );
        assertFalse(immediate);
        assertEq(delay, 600);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyPolicyLAP),
                RoyaltyPolicyLAP.upgradeVaults.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(accessController),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(accessController),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(licenseToken),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(licenseToken),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(disputeModule),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(disputeModule),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(arbitrationPolicySP),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(arbitrationPolicySP),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(licensingModule),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(licensingModule),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(royaltyModule),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyModule),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(licenseRegistry),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(licenseRegistry),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(moduleRegistry),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(moduleRegistry),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(ipAssetRegistry),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(ipAssetRegistry),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );

        (immediate, delay) = protocolAccessManager.canCall(
            multisig,
            address(royaltyPolicyLAP),
            UUPSUpgradeable.upgradeToAndCall.selector
        );
        assertFalse(immediate);
        assertEq(delay, execDelay);
        assertEq(
            protocolAccessManager.getTargetFunctionRole(
                address(royaltyPolicyLAP),
                UUPSUpgradeable.upgradeToAndCall.selector
            ),
            ProtocolAdmin.UPGRADER_ROLE
        );
    }
}
