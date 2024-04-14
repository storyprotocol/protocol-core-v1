// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ProtocolAdmin } from "contracts/lib/ProtocolAdmin.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

import { MockIpRoyaltyVaultV2 } from "../mocks/module/MockIpRoyaltyVaultV2.sol";

contract IPRoyaltyVaults is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.prank(u.admin);
        protocolAccessManager.grantRole(ProtocolAdmin.UPGRADER_ROLE, u.alice, upgraderExecDelay);
    }

    function test_upgradeVaults() public {
        address newVault = address(new MockIpRoyaltyVaultV2(address(royaltyPolicyLAP), address(disputeModule)));
        (bool immediate, uint32 delay) = protocolAccessManager.canCall(
            u.alice,
            address(royaltyPolicyLAP),
            RoyaltyPolicyLAP.upgradeVaults.selector
        );
        assertFalse(immediate);
        assertEq(delay, 600);
        vm.prank(u.alice);
        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            address(royaltyPolicyLAP),
            abi.encodeCall(RoyaltyPolicyLAP.upgradeVaults, (newVault)),
            0 // earliest time possible, upgraderExecDelay
        );
        vm.warp(upgraderExecDelay + 1);

        vm.prank(u.alice);
        royaltyPolicyLAP.upgradeVaults(newVault);

        assertEq(ipRoyaltyVaultBeacon.implementation(), newVault);
    }
}
