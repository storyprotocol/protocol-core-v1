// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";
import { BaseModule } from "../../contracts/modules/BaseModule.sol";
import { Errors } from "../../contracts/lib/Errors.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract IPAccountStorageTest is BaseTest, BaseModule {
    MockModule public module;
    IIPAccount public ipAccount;

    string public override name = "IPAccountStorageTest";

    function setUp() public override {
        super.setUp();

        module = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");

        address owner = vm.addr(1);
        uint256 tokenId = 100;
        mockNFT.mintId(owner, tokenId);
        ipAccount = IIPAccount(payable(ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId)));
        vm.startPrank(admin);
        moduleRegistry.registerModule("MockModule", address(module));
        moduleRegistry.registerModule("IPAccountStorageTest", address(this));
        vm.stopPrank();
    }

    function test_IPAccountStorage_storeBytes() public {
        ipAccount.setBytes("test", abi.encodePacked("test"));
        assertEq(ipAccount.getBytes("test"), "test");
    }

    function test_IPAccountStorage_readBytes_DifferentNamespace() public {
        vm.prank(address(module));
        ipAccount.setBytes("test", abi.encodePacked("test"));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes(_toBytes32(address(module)), "test"), "test");
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
        vm.prank(address(module));
        ipAccount.setBytes("test", abi.encode(addresses));
        vm.prank(vm.addr(2));
        address[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(address(module)), "test"), (address[]));
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
        vm.prank(address(module));
        ipAccount.setBytes("test", abi.encode(uints));
        vm.prank(vm.addr(2));
        uint256[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(address(module)), "test"), (uint256[]));
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
        vm.prank(address(module));
        ipAccount.setBytes("test", abi.encode(strings));
        vm.prank(vm.addr(2));
        string[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(address(module)), "test"), (string[]));
        assertEq(result[0], "test1");
        assertEq(result[1], "test2");
    }

    function test_IPAccountStorage_storeBytes32() public {
        ipAccount.setBytes32("test", bytes32(uint256(111)));
        assertEq(ipAccount.getBytes32("test"), bytes32(uint256(111)));
    }

    function test_IPAccountStorage_readBytes32_differentNameSpace() public {
        vm.prank(address(module));
        ipAccount.setBytes32("test", bytes32(uint256(111)));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes32(_toBytes32(address(module)), "test"), bytes32(uint256(111)));
    }

    function test_IPAccountStorage_storeBytes32String() public {
        ipAccount.setBytes32("test", "testData");
        assertEq(ipAccount.getBytes32("test"), "testData");
    }

    function test_IPAccountStorage_readBytes32String_differentNameSpace() public {
        vm.prank(address(module));
        ipAccount.setBytes32("test", "testData");
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes32(_toBytes32(address(module)), "test"), "testData");
    }

    function test_IPAccountStorage_setBytes32_revert_NonRegisteredModule() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccountStorage__NotRegisteredModule.selector, address(0x123)));
        vm.prank(address(0x123));
        ipAccount.setBytes32("test", "testData");
    }

    function test_IPAccountStorage_setBytes_revert_NonRegisteredModule() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccountStorage__NotRegisteredModule.selector, address(0x123)));
        vm.prank(address(0x123));
        ipAccount.setBytes("test", "testData");
    }

    function test_IPAccountStorage_setBytes_ByIpAssetRegistry() public {
        vm.prank(address(ipAssetRegistry));
        ipAccount.setBytes("test", "testData");
        assertEq(ipAccount.getBytes(_toBytes32(address(ipAssetRegistry)), "test"), "testData");
    }

    function test_IPAccountStorage_setBytes32_ByIpAssetRegistry() public {
        vm.prank(address(ipAssetRegistry));
        ipAccount.setBytes32("test", "testData");
        assertEq(ipAccount.getBytes32(_toBytes32(address(ipAssetRegistry)), "test"), "testData");
    }

    function test_IPAccountStorage_setBytes_ByLicenseRegistry() public {
        vm.prank(address(licenseRegistry));
        ipAccount.setBytes("test", "testData");
        assertEq(ipAccount.getBytes(_toBytes32(address(licenseRegistry)), "test"), "testData");
    }

    function test_IPAccountStorage_setBytes32_ByLicenseRegistry() public {
        vm.prank(address(licenseRegistry));
        ipAccount.setBytes32("test", "testData");
        assertEq(ipAccount.getBytes32(_toBytes32(address(licenseRegistry)), "test"), "testData");
    }

    function test_IPAccountStorage_BatchSetAndGetBytes() public {
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = "test1";
        keys[1] = "test2";
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked("test1Data");
        values[1] = abi.encodePacked("test2Data");
        ipAccount.setBytesBatch(keys, values);
        assertEq(ipAccount.getBytes("test1"), "test1Data");
        assertEq(ipAccount.getBytes("test2"), "test2Data");

        bytes32[] memory namespaces = new bytes32[](2);
        namespaces[0] = _toBytes32(address(this));
        namespaces[1] = _toBytes32(address(this));
        bytes[] memory results = ipAccount.getBytesBatch(namespaces, keys);
        assertEq(results[0], "test1Data");
        assertEq(results[1], "test2Data");
    }

    function test_IPAccountStorage_revert_BatchSetAndGetBytes() public {
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = "test1";
        keys[1] = "test2";
        bytes[] memory values = new bytes[](1);
        values[0] = abi.encodePacked("test1Data");
        vm.expectRevert(Errors.IPAccountStorage__InvalidBatchLengths.selector);
        ipAccount.setBytesBatch(keys, values);

        bytes32[] memory namespaces = new bytes32[](1);
        namespaces[0] = _toBytes32(address(this));
        vm.expectRevert(Errors.IPAccountStorage__InvalidBatchLengths.selector);
        ipAccount.getBytesBatch(namespaces, keys);
    }

    function test_IPAccountStorage_BatchSetAndGetBytes32() public {
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = "test1";
        keys[1] = "test2";
        bytes32[] memory values = new bytes32[](2);
        values[0] = bytes32(uint256(111));
        values[1] = bytes32(uint256(222));
        ipAccount.setBytes32Batch(keys, values);
        assertEq(ipAccount.getBytes32("test1"), bytes32(uint256(111)));
        assertEq(ipAccount.getBytes32("test2"), bytes32(uint256(222)));

        bytes32[] memory namespaces = new bytes32[](2);
        namespaces[0] = _toBytes32(address(this));
        namespaces[1] = _toBytes32(address(this));
        bytes32[] memory results = ipAccount.getBytes32Batch(namespaces, keys);
        assertEq(results[0], bytes32(uint256(111)));
        assertEq(results[1], bytes32(uint256(222)));
    }

    function test_IPAccountStorage_revert_BatchSetAndGetBytes32() public {
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = "test1";
        keys[1] = "test2";
        bytes32[] memory values = new bytes32[](1);
        values[0] = bytes32(uint256(111));
        vm.expectRevert(Errors.IPAccountStorage__InvalidBatchLengths.selector);
        ipAccount.setBytes32Batch(keys, values);

        bytes32[] memory namespaces = new bytes32[](1);
        namespaces[0] = _toBytes32(address(this));
        vm.expectRevert(Errors.IPAccountStorage__InvalidBatchLengths.selector);
        ipAccount.getBytes32Batch(namespaces, keys);
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
