// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { IPAccountStorageOps } from "../../contracts/lib/IPAccountStorageOps.sol";
import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract IPAccountStorageOpsTest is BaseTest {
    using ShortStrings for *;

    MockModule public module;
    IIPAccount public ipAccount;

    function setUp() public override {
        super.setUp();
        deployConditionally();
        postDeploymentSetup();

        module = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");

        address owner = vm.addr(1);
        uint256 tokenId = 100;
        mockNFT.mintId(owner, tokenId);
        ipAccount = IIPAccount(payable(ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId)));
    }

    function test_IPAccountStorageOps_setString_ShortString() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setString(ipAccount, "test".toShortString(), "test");
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getString(ipAccount, "test".toShortString()), "test");
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getString(ipAccount, vm.addr(1), "test".toShortString()), "test");
    }

    function test_IPAccountStorageOps_setString_bytes32() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setString(ipAccount, bytes32("test"), "test");
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getString(ipAccount, "test".toShortString()), "test");
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getString(ipAccount, vm.addr(1), "test".toShortString()), "test");
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getString(ipAccount, vm.addr(1), bytes32("test")), "test");
    }

    function test_IPAccountStorageOps_setAddress_ShortString() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setAddress(ipAccount, "test".toShortString(), vm.addr(2));
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, "test".toShortString()), vm.addr(2));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, vm.addr(1), "test".toShortString()), vm.addr(2));
    }

    function test_IPAccountStorageOps_setAddress_bytes32() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setAddress(ipAccount, bytes32("test"), vm.addr(2));
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, "test".toShortString()), vm.addr(2));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, vm.addr(1), "test".toShortString()), vm.addr(2));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, vm.addr(1), bytes32("test")), vm.addr(2));
    }

    function test_IPAccountStorageOps_setUint256_ShortString() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setUint256(ipAccount, "test".toShortString(), 1);
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getUint256(ipAccount, "test".toShortString()), 1);
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getUint256(ipAccount, vm.addr(1), "test".toShortString()), 1);
    }

    function test_IPAccountStorageOps_setUint256_bytes32() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setUint256(ipAccount, bytes32("test"), 1);
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getUint256(ipAccount, "test".toShortString()), 1);
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getUint256(ipAccount, vm.addr(1), "test".toShortString()), 1);
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getUint256(ipAccount, vm.addr(1), bytes32("test")), 1);
    }

    function test_IPAccountStorageOps_setBool_ShortString() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setBool(ipAccount, "test".toShortString(), true);
        vm.prank(vm.addr(1));
        assertTrue(IPAccountStorageOps.getBool(ipAccount, "test".toShortString()));
        vm.prank(vm.addr(2));
        assertTrue(IPAccountStorageOps.getBool(ipAccount, vm.addr(1), "test".toShortString()));
    }

    function test_IPAccountStorageOps_setBool_bytes32() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setBool(ipAccount, bytes32("test"), true);
        vm.prank(vm.addr(1));
        assertTrue(IPAccountStorageOps.getBool(ipAccount, "test".toShortString()));
        vm.prank(vm.addr(2));
        assertTrue(IPAccountStorageOps.getBool(ipAccount, vm.addr(1), "test".toShortString()));
        vm.prank(vm.addr(2));
        assertTrue(IPAccountStorageOps.getBool(ipAccount, vm.addr(1), bytes32("test")));
    }

    function test_IPAccountStorageOps_setBytes_ShortString() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setBytes(ipAccount, "test".toShortString(), abi.encodePacked("test"));
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getBytes(ipAccount, "test".toShortString()), abi.encodePacked("test"));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getBytes(ipAccount, vm.addr(1), "test".toShortString()), abi.encodePacked("test"));
    }

    function test_IPAccountStorageOps_setBytes_bytes32() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes(bytes32("test"), abi.encodePacked("test"));
        vm.prank(vm.addr(1));
        assertEq(IPAccountStorageOps.getBytes(ipAccount, "test".toShortString()), abi.encodePacked("test"));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getBytes(ipAccount, vm.addr(1), "test".toShortString()), abi.encodePacked("test"));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getBytes(ipAccount, vm.addr(1), bytes32("test")), abi.encodePacked("test"));
    }

    function test_IPAccountStorageOps_setBytes_2_keys() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setBytes(
            ipAccount,
            "key1".toShortString(),
            "key2".toShortString(),
            abi.encodePacked("test")
        );
        vm.prank(vm.addr(1));
        assertEq(
            IPAccountStorageOps.getBytes(ipAccount, "key1".toShortString(), "key2".toShortString()),
            abi.encodePacked("test")
        );
        vm.prank(vm.addr(2));
        assertEq(
            IPAccountStorageOps.getBytes(ipAccount, vm.addr(1), "key1".toShortString(), "key2".toShortString()),
            abi.encodePacked("test")
        );
    }

    function test_IPAccountStorage_storeUint256() public {
        IPAccountStorageOps.setUint256(ipAccount, "test", 1);
        assertEq(IPAccountStorageOps.getUint256(ipAccount, "test"), 1);
    }

    function test_IPAccountStorage_readUint256_differentNameSpace() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setUint256(ipAccount, "test", 1);
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getUint256(ipAccount, _toBytes32(vm.addr(1)), "test"), 1);
    }

    function test_IPAccountStorage_storeBool() public {
        IPAccountStorageOps.setBool(ipAccount, "test", true);
        assertTrue(IPAccountStorageOps.getBool(ipAccount, "test"));
    }

    function test_IPAccountStorage_readBool_differentNameSpace() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setBool(ipAccount, "test", true);
        vm.prank(vm.addr(2));
        assertTrue(IPAccountStorageOps.getBool(ipAccount, _toBytes32(vm.addr(1)), "test"));
    }

    function test_IPAccountStorage_storeString() public {
        IPAccountStorageOps.setString(ipAccount, "test", "test");
        assertEq(IPAccountStorageOps.getString(ipAccount, "test"), "test");
    }

    function test_IPAccountStorage_readString_differentNameSpace() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setString(ipAccount, "test", "test");
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getString(ipAccount, _toBytes32(vm.addr(1)), "test"), "test");
    }

    function test_IPAccountStorage_storeAddress() public {
        IPAccountStorageOps.setAddress(ipAccount, "test", vm.addr(1));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, "test"), vm.addr(1));
    }

    function test_IPAccountStorage_readAddress_differentNameSpace() public {
        vm.prank(vm.addr(1));
        IPAccountStorageOps.setAddress(ipAccount, "test", vm.addr(1));
        vm.prank(vm.addr(2));
        assertEq(IPAccountStorageOps.getAddress(ipAccount, _toBytes32(vm.addr(1)), "test"), vm.addr(1));
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
