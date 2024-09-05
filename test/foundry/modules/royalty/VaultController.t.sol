// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { VaultController } from "../../../../contracts/modules/royalty/policies/VaultController.sol";

// contracts
import { IpRoyaltyVault } from "../../../../contracts/modules/royalty/policies/IpRoyaltyVault.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

// tests
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestRoyaltyModule is BaseTest {
    function setUp() public override {
        super.setUp();
        vm.startPrank(u.admin);
    }

    function test_VaultController_setSnapshotInterval() public {
        uint256 timestampInterval = 100;
        royaltyModule.setSnapshotInterval(timestampInterval);
        assertEq(royaltyModule.snapshotInterval(), timestampInterval);
    }

    function test_VaultController_setIpRoyaltyVaultBeacon_revert_ZeroIpRoyaltyVaultBeacon() public {
        vm.expectRevert(Errors.VaultController__ZeroIpRoyaltyVaultBeacon.selector);
        royaltyModule.setIpRoyaltyVaultBeacon(address(0));
    }

    function test_VaultController_setIpRoyaltyVaultBeacon() public {
        address beacon = address(0x1);
        royaltyModule.setIpRoyaltyVaultBeacon(beacon);
        assertEq(royaltyModule.ipRoyaltyVaultBeacon(), beacon);
    }

    function test_VaultController_upgradeVaults() public {
        address newVault = address(new IpRoyaltyVault(address(1), address(2)));

        (bytes32 operationId, uint32 nonce) = protocolAccessManager.schedule(
            address(royaltyModule),
            abi.encodeCall(VaultController.upgradeVaults, (newVault)),
            0 // earliest time possible, upgraderExecDelay
        );
        vm.warp(upgraderExecDelay + 1);

        royaltyModule.upgradeVaults(newVault);
        assertEq(UpgradeableBeacon(royaltyModule.ipRoyaltyVaultBeacon()).implementation(), newVault);
    }
}
