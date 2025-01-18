// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { BaseTest } from "../utils/BaseTest.t.sol";
import { IIPGraphACL } from "../../../contracts/interfaces/access/IIPGraphACL.sol";

contract IPGraphACLTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    // test allow/disallow
    // test add/remove whitelist
    // onlyWhitelisted modifier

    function test_IPGraphACL_addToWhitelist() public {
        vm.prank(admin);
        vm.expectEmit();
        emit IIPGraphACL.WhitelistedAddress(address(0x123));
        ipGraphACL.whitelistAddress(address(0x123));
        vm.prank(address(0x123));
        assertTrue(ipGraphACL.isWhitelisted(address(0x123)));
    }

    function test_IPGraphACL_revert_removeFromWhitelist() public {
        vm.prank(admin);
        ipGraphACL.whitelistAddress(address(0x123));
        vm.prank(address(0x123));
        assertTrue(ipGraphACL.isWhitelisted(address(0x123)));
        vm.prank(admin);
        vm.expectEmit();
        emit IIPGraphACL.RevokedWhitelistedAddress(address(0x123));
        ipGraphACL.revokeWhitelistedAddress(address(0x123));
        assertFalse(ipGraphACL.isWhitelisted(address(0x123)));
        vm.prank(address(0x123));
    }
}
