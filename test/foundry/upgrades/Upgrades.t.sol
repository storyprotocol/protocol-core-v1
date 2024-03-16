// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// Contracts
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { MockLicenseRegistryV2 } from "test/foundry/mocks/registry/MockLicenseRegistryV2.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract UpgradesTest is BaseTest {

    function setUp() public override {
        super.setUp();
        deployIntegration();
    }

    function test_upgrade_licenseRegistry_mock() public {

        vm.startPrank(u.admin);
        // Set storage in previous contract
        LicenseRegistry(address(licenseRegistry)).setLicensingModule(address(licensingModule));

        Upgrades.upgradeProxy(
            address(licenseRegistry),
            "MockLicenseRegistryV2.sol",
            abi.encodeCall(MockLicenseRegistryV2.setFoo, ("bar"))
        );
        // Set new storage
        MockLicenseRegistryV2(address(licenseRegistry)).setFoo("bar");
        
        // New storage is here.
        assertEq(MockLicenseRegistryV2(address(licenseRegistry)).foo(), "bar");

        // Old storage is still there.
        assertEq(address(licenseRegistry.licensingModule()), address(licensingModule));
    }


}