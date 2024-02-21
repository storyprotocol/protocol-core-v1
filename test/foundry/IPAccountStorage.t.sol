// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract IPAccountStorageTest is BaseTest {
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

    function test_IPAccountStorage_storeBytes() public {
        ipAccount.setBytes("test", abi.encodePacked("test"));
        assertEq(ipAccount.getBytes("test"), "test");
    }

    function test_IPAccountStorage_readBytes_DifferentNamespace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encodePacked("test"));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), "test");
    }

    function test_IPAccountStorage_storeAddressArray() public {
        address[] memory addresses = new address[](2);
        addresses[0] = vm.addr(1);
        addresses[1] = vm.addr(2);
        ipAccount.setBytes("test", abi.encode(addresses));
        address[] memory result = abi.decode(ipAccount.getBytes("test"), (address[]));
        assertEq(result[0], vm.addr(1));
        assertEq(result[1], vm.addr(2));
    }

    function test_IPAccountStorage_readAddressArray_differentNameSpace() public {
        address[] memory addresses = new address[](2);
        addresses[0] = vm.addr(1);
        addresses[1] = vm.addr(2);
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encode(addresses));
        vm.prank(vm.addr(2));
        address[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), (address[]));
        assertEq(result[0], vm.addr(1));
        assertEq(result[1], vm.addr(2));
    }

    function test_IPAccountStorage_storeUint256Array() public {
        uint256[] memory uints = new uint256[](2);
        uints[0] = 1;
        uints[1] = 2;
        ipAccount.setBytes("test", abi.encode(uints));
        uint256[] memory result = abi.decode(ipAccount.getBytes("test"), (uint256[]));
        assertEq(result[0], 1);
        assertEq(result[1], 2);
    }

    function test_IPAccountStorage_readUint256Array_differentNameSpace() public {
        uint256[] memory uints = new uint256[](2);
        uints[0] = 1;
        uints[1] = 2;
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encode(uints));
        vm.prank(vm.addr(2));
        uint256[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), (uint256[]));
        assertEq(result[0], 1);
        assertEq(result[1], 2);
    }

    function test_IPAccountStorage_storeStringArray() public {
        string[] memory strings = new string[](2);
        strings[0] = "test1";
        strings[1] = "test2";
        ipAccount.setBytes("test", abi.encode(strings));
        string[] memory result = abi.decode(ipAccount.getBytes("test"), (string[]));
        assertEq(result[0], "test1");
        assertEq(result[1], "test2");
    }

    function test_IPAccountStorage_readStringArray_differentNameSpace() public {
        string[] memory strings = new string[](2);
        strings[0] = "test1";
        strings[1] = "test2";
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encode(strings));
        vm.prank(vm.addr(2));
        string[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), (string[]));
        assertEq(result[0], "test1");
        assertEq(result[1], "test2");
    }

    function test_IPAccountStorage_storeBytes32() public {
        ipAccount.setBytes32("test", bytes32(uint256(111)));
        assertEq(ipAccount.getBytes32("test"), bytes32(uint256(111)));
    }

    function test_IPAccountStorage_readBytes32_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes32("test", bytes32(uint256(111)));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes32(_toBytes32(vm.addr(1)), "test"), bytes32(uint256(111)));
    }

    function test_IPAccountStorage_storeBytes32String() public {
        ipAccount.setBytes32("test", "testData");
        assertEq(ipAccount.getBytes32("test"), "testData");
    }

    function test_IPAccountStorage_readBytes32String_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes32("test", "testData");
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes32(_toBytes32(vm.addr(1)), "test"), "testData");
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
