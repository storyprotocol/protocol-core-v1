// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IPAccountImpl } from "../../../contracts/IPAccountImpl.sol";
import { IPAccountChecker } from "../../../contracts/lib/registries/IPAccountChecker.sol";
import { IPAccountRegistry } from "../../../contracts/registries/IPAccountRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

contract MockIPAccountRegistry is IPAccountRegistry {
    constructor(address erc6551Registry, address ipAccountImpl) IPAccountRegistry(erc6551Registry, ipAccountImpl) {}
}

contract IPAccountRegistryTest is BaseTest {
    using IPAccountChecker for IPAccountRegistry;

    uint256 internal chainId = 100;
    address internal tokenAddress = address(200);
    uint256 internal tokenId = 300;

    function setUp() public override {
        super.setUp();
    }

    function test_IPAccountRegistry_registerIpAccount() public {
        address ipAccountAddr = ipAssetRegistry.register(chainId, tokenAddress, tokenId);

        address registryComputedAddress = ipAccountRegistry.ipAccount(chainId, tokenAddress, tokenId);
        assertEq(ipAccountAddr, registryComputedAddress);

        IPAccountImpl ipAccount = IPAccountImpl(payable(ipAccountAddr));

        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAccount.token();
        assertEq(chainId_, chainId);
        assertEq(tokenAddress_, tokenAddress);
        assertEq(tokenId_, tokenId);

        assertTrue(ipAssetRegistry.isRegistered(ipAccountAddr));
    }

    function test_IPAccountRegistry_constructor_revert() public {
        vm.expectRevert(Errors.IPAccountRegistry_ZeroERC6551Registry.selector);
        new MockIPAccountRegistry(address(0), address(123));
        vm.expectRevert(Errors.IPAccountRegistry_ZeroIpAccountImpl.selector);
        new MockIPAccountRegistry(address(123), address(0));
    }
}
