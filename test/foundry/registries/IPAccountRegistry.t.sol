// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IPAccountImpl } from "../../../contracts/IPAccountImpl.sol";
import { IPAccountChecker } from "../../../contracts/lib/registries/IPAccountChecker.sol";
import { IPAccountRegistry } from "../../../contracts/registries/IPAccountRegistry.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

contract IPAccountRegistryTest is BaseTest {
    using IPAccountChecker for IPAccountRegistry;

    uint256 internal chainId = 100;
    address internal tokenAddress = address(200);
    uint256 internal tokenId = 300;

    function setUp() public override {
        super.setUp();
    }

    function test_IPAccountRegistry_registerIpAccount() public {
        address ipAccountAddr = ipAccountRegistry.registerIpAccount(chainId, tokenAddress, tokenId);

        address registryComputedAddress = ipAccountRegistry.ipAccount(chainId, tokenAddress, tokenId);
        assertEq(ipAccountAddr, registryComputedAddress);

        IPAccountImpl ipAccount = IPAccountImpl(payable(ipAccountAddr));

        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAccount.token();
        assertEq(chainId_, chainId);
        assertEq(tokenAddress_, tokenAddress);
        assertEq(tokenId_, tokenId);

        assertTrue(ipAccountRegistry.isRegistered(chainId, tokenAddress, tokenId));
    }
}
