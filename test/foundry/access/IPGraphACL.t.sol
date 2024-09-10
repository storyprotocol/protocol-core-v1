// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Errors } from "../../../contracts/lib/Errors.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract IPGraphACLTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    // test allow/disallow
    // test add/remove whitelist
    // onlyWhitelisted modifier

    function test_IPGraphACL_initialized_not_allow() public {
        assertFalse(ipGraphACL.isAllowed());
    }

    function test_IPGraphACL_allow() public {
        vm.prank(address(licenseRegistry));
        ipGraphACL.allow();
        assertTrue(ipGraphACL.isAllowed());
    }

    function test_IPGraphACL_disallow() public {
        vm.prank(address(licenseRegistry));
        ipGraphACL.disallow();
        assertFalse(ipGraphACL.isAllowed());
    }

    function test_IPGraphACL_addToWhitelist() public {
        vm.prank(admin);
        ipGraphACL.whitelistAddress(address(0x123));
        vm.prank(address(0x123));
        ipGraphACL.allow();
        assertTrue(ipGraphACL.isAllowed());
    }

    function test_IPGraphACL_revert_removeFromWhitelist() public {
        vm.prank(admin);
        ipGraphACL.whitelistAddress(address(0x123));
        vm.prank(address(0x123));
        ipGraphACL.allow();
        assertTrue(ipGraphACL.isAllowed());
        vm.prank(admin);
        ipGraphACL.revokeWhitelistedAddress(address(0x123));
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSelector(Errors.IPGraphACL__NotWhitelisted.selector, address(0x123)));
        ipGraphACL.disallow();
    }
}
