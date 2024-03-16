// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicenseRegistryV2Mock } from "contracts/test-mocks/LicenseRegistryV2Mock.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract UpgradesTest is BaseTest {

    function setUp() public override {
        super.setUp();
    }

    function test_upgrade_mock() public {
        
        Upgrades.upgradeProxy(
            address(licenseRegistry),
            "LicenseRegistryV2Mock.sol",
            ""
        );
        LicenseRegistryV2Mock(address(licenseRegistry)).setFoo("bar");
        // New storage is here.
        assertEq(LicenseRegistryV2Mock(address(licenseRegistry)).foo(), "bar");
        // Old storage is still there.
        assertEq(address(licenseRegistry.licensingModule()), address(licensingModule));
    }

    
}
